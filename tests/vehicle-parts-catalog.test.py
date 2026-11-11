"""Source-catalog regression checks; no engine or rendered assets required."""
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('catalog', ROOT / 'tools/vehicles/parts-catalog.py')
catalog = importlib.util.module_from_spec(spec)
spec.loader.exec_module(catalog)


class PartsCatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = catalog.build()

    def test_every_active_model_is_cataloged_without_variant_inflation(self):
        data = self.data
        self.assertEqual(set(data['models']), set(catalog.indexer.make_index(ROOT)['models']))
        self.assertEqual(data['models']['blackwasp']['owner'], 'VmFighter')
        for row in data['ranking']:
            self.assertEqual(row['design_count'], len(row['evidence']))
            for design in row['evidence']:
                self.assertTrue(data['designs'][design]['counted'])
                self.assertNotIn('truck', data['designs'][design]['models'])

    def test_sections_retain_unlabelled_code_and_ignore_next_function_docs(self):
        item = {'file': 'sample.gd', 'line': 10, 'body':
                'static func _example():\n\tk._box()\n\t# door\n\n\t# hinges\n\tk._cyl()\n\n## Next function: radar\n'}
        sections = catalog.sections('VmCore._example', item)
        self.assertEqual(len(sections), 2)
        self.assertEqual(sections[0]['label'], 'Unlabelled construction / setup')
        self.assertEqual(sections[1]['label'], 'door hinges')
        self.assertNotIn('radar', str(sections))

    def test_shared_adopters_and_unrelated_terms_do_not_rank(self):
        data = self.data
        for row in data['ranking']:
            for refs in row['evidence'].values():
                for ref in refs:
                    section = data['sections'][ref]
                    self.assertTrue(section['local_geometry'])
                    self.assertFalse(any(api.startswith(prefix) for api in section['shared']
                                         for prefix in row.get('shared', [])))
        rows = {r['name']: r for r in data['ranking']}
        for name, function, label in [
            ('Marine propellers and rudders', 'VmFighter._f16', 'fin with rudder'),
            ('Marine propellers and rudders', 'VmShips._patrol_ship', 'liferafts tipped outboard'),
            ('Aircraft skids', 'VmBoat._surc', 'non-skid decks'),
            ('Towing pintles and hitches', 'VmHeli._ghost_hawk', 'miniguns on pintles'),
            ('Gun receivers and breech housings', 'VmCore._apache', 'radar warning receivers'),
        ]:
            self.assertFalse(catalog.matches_category(rows[name], {'function': function, 'label': label}))
        self.assertTrue(catalog.matches_category(rows['Track drive sprockets'],
            {'function': 'VmCore._sprocket', 'label': 'Unlabelled construction / setup'}))


if __name__ == '__main__':
    unittest.main()

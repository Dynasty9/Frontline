use crate::{
    collision_index::CollisionIndexCore, path_planner::PathPlannerCore, terrain::TerrainCore,
};
use frontline_core::cover::{Anchor, AnchorKind};
use frontline_core::cover_search::{self, Input, NearbyClaim, Scene, SquadClaim, Structure};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct CoverSearchCore {
    base: Base<RefCounted>,
}

fn row(value: Variant, length: usize) -> Option<Array<Variant>> {
    let row: Array<Variant> = value.try_to().ok()?;
    (row.len() == length).then_some(row)
}

fn id(value: Variant) -> Option<u64> {
    u64::try_from(value.try_to::<i64>().ok()?).ok()
}

fn structures(rows: &Array<Variant>) -> Option<Vec<Structure>> {
    if rows.len() > 100_000 {
        return None;
    }
    let mut total = 0;
    rows.iter_shared()
        .map(|v| {
            let v = row(v, 8)?;
            let positions: PackedVector3Array = v.get(4)?.try_to().ok()?;
            let normals: PackedVector3Array = v.get(5)?.try_to().ok()?;
            let heights: PackedFloat32Array = v.get(6)?.try_to().ok()?;
            let kinds: PackedByteArray = v.get(7)?.try_to().ok()?;
            total += positions.len();
            if total > 1_000_000
                || positions.len() > 100_000
                || positions.len() != normals.len()
                || positions.len() != heights.len()
                || positions.len() != kinds.len()
            {
                return None;
            }
            let positions = (0..positions.len())
                .map(|i| {
                    Some(Anchor {
                        position: crate::point(positions[i]),
                        normal: crate::point(normals[i]),
                        height: f64::from(heights[i]),
                        kind: match kinds[i] {
                            1 => AnchorKind::Over,
                            2 => AnchorKind::EdgeLeft,
                            3 => AnchorKind::EdgeRight,
                            4 => AnchorKind::Shelter,
                            5 => AnchorKind::Stack,
                            _ => return None,
                        },
                    })
                })
                .collect::<Option<Vec<_>>>()?;
            Some(Structure {
                id: id(v.get(0)?)?,
                built: v.get(1)?.try_to().ok()?,
                burn: v.get(2)?.try_to().ok()?,
                material: u8::try_from(v.get(3)?.try_to::<i64>().ok()?).ok()?,
                positions,
            })
        })
        .collect()
}

#[godot_api]
impl CoverSearchCore {
    #[func]
    #[allow(clippy::too_many_arguments)]
    fn find(
        &self,
        input: Array<Variant>,
        threats: PackedVector3Array,
        buildings: Array<Variant>,
        mates: Array<Variant>,
        nearby: Array<Variant>,
        heat: PackedByteArray,
        deck: PackedByteArray,
        terrain: Gd<TerrainCore>,
        navigation: Gd<PathPlannerCore>,
        mut collision: Gd<CollisionIndexCore>,
    ) -> Array<Variant> {
        self.find_checked(
            input,
            threats,
            buildings,
            mates,
            nearby,
            heat,
            deck,
            terrain,
            navigation,
            &mut collision,
        )
        .unwrap_or_default()
    }
}

impl CoverSearchCore {
    #[allow(clippy::too_many_arguments)]
    fn find_checked(
        &self,
        input: Array<Variant>,
        threats: PackedVector3Array,
        buildings: Array<Variant>,
        mates: Array<Variant>,
        nearby: Array<Variant>,
        heat: PackedByteArray,
        deck: PackedByteArray,
        terrain: Gd<TerrainCore>,
        navigation: Gd<PathPlannerCore>,
        collision: &mut Gd<CollisionIndexCore>,
    ) -> Option<Array<Variant>> {
        if input.len() != 11
            || threats.len() > 4096
            || mates.len() > 100_000
            || nearby.len() > 100_000
        {
            return None;
        }
        let input = Input {
            id: id(input.get(0)?)?,
            team: input.get(1)?.try_to().ok()?,
            position: crate::point(input.get(2)?.try_to().ok()?),
            anchor: crate::point(input.get(3)?.try_to().ok()?),
            radius: input.get(4)?.try_to().ok()?,
            grouped: input.get(5)?.try_to().ok()?,
            prone: input.get(6)?.try_to().ok()?,
            unarmed: input.get(7)?.try_to().ok()?,
            weapon_range: input.get(8)?.try_to().ok()?,
            current_structure: id(input.get(9)?)?,
            current_anchor: input.get(10)?.try_to().ok()?,
        };
        let threats: Vec<_> = threats
            .as_slice()
            .iter()
            .copied()
            .map(crate::point)
            .collect();
        let result = with_scene(
            buildings,
            mates,
            nearby,
            heat,
            deck,
            terrain,
            navigation,
            collision,
            |scene| cover_search::find(input, &threats, scene).ok(),
        )?;
        let p = |p: frontline_core::vector::Vector3| Vector3::new(p.x, p.y, p.z);
        let choice = result.choice.map_or_else(Array::new, |c| {
            varray![
                c.evaluation.kind as i32,
                c.evaluation.protection,
                c.evaluation.fire,
                p(c.evaluation.lean),
                p(c.evaluation.threat_direction),
                p(c.position),
                p(c.normal),
                c.height,
                i32::from(c.material),
                c.structure as i64,
                c.anchor
            ]
        });
        Some(varray![
            result.candidates as i64,
            result.evaluations as i64,
            &choice
        ])
    }
}

#[allow(clippy::too_many_arguments)]
pub(crate) fn with_scene<T>(
    buildings: Array<Variant>,
    mates: Array<Variant>,
    nearby: Array<Variant>,
    heat: PackedByteArray,
    deck: PackedByteArray,
    terrain: Gd<TerrainCore>,
    navigation: Gd<PathPlannerCore>,
    collision: &mut Gd<CollisionIndexCore>,
    apply: impl FnOnce(&mut Scene<'_>) -> Option<T>,
) -> Option<T> {
    if mates.len() > 100_000 || nearby.len() > 100_000 {
        return None;
    }
    let buildings = structures(&buildings)?;
    let mates = mates
        .iter_shared()
        .map(|v| {
            let v = row(v, 4)?;
            Some(SquadClaim {
                id: id(v.get(0)?)?,
                alive: v.get(1)?.try_to().ok()?,
                covering: v.get(2)?.try_to().ok()?,
                position: crate::point(v.get(3)?.try_to().ok()?),
            })
        })
        .collect::<Option<Vec<_>>>()?;
    let nearby = nearby
        .iter_shared()
        .map(|v| {
            let v = row(v, 7)?;
            let cell: Vector2i = v.get(6)?.try_to().ok()?;
            Some(NearbyClaim {
                id: id(v.get(0)?)?,
                team: v.get(1)?.try_to().ok()?,
                alive: v.get(2)?.try_to().ok()?,
                gone: v.get(3)?.try_to().ok()?,
                position: crate::point(v.get(4)?.try_to().ok()?),
                cover_position: crate::point(v.get(5)?.try_to().ok()?),
                cell: [cell.x, cell.y],
            })
        })
        .collect::<Option<Vec<_>>>()?;

    let terrain = terrain.bind();
    let navigation = navigation.bind();
    let mut collision = collision.bind_mut();
    apply(&mut Scene {
        terrain: terrain.core.as_ref()?,
        navigation: navigation.core.as_ref()?,
        collision: &mut collision.core,
        heat: heat.as_slice(),
        deck: deck.as_slice(),
        structures: &buildings,
        squad_claims: &mates,
        nearby_claims: &nearby,
    })
}

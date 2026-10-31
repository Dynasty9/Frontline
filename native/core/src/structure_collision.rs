//! Structure collision follows authoritative parts; cosmetic tilt does not move its shelter.
use crate::collision::{BoxShape, Mat3};
use crate::cover::{rotation, transform};
use crate::structure::Structure;
use crate::world_geometry::WorldGeometry;

impl Structure {
    pub fn collision_shapes(&self) -> Result<Vec<BoxShape>, &'static str> {
        if !self.valid() || self.gone {
            return Err("invalid structure collision state");
        }
        let mut shapes = vec![];
        if !self.built {
            return Ok(shapes);
        }
        let basis = rotation(self.yaw);
        for part in self.parts.iter().filter(|p| p.collision) {
            if part.size.min_element() <= 0.0 || shapes.len() >= 4096 {
                return Err("invalid structure collision part");
            }
            let local = rotation(part.yaw);
            shapes.push(BoxShape {
                body: i64::from(self.id),
                shape: shapes.len() as i32,
                center: self.position + transform(basis, part.position),
                basis: Mat3::from_cols(
                    transform(basis, local.x_axis),
                    transform(basis, local.y_axis),
                    transform(basis, local.z_axis),
                ),
                half: part.size * 0.5,
            });
        }
        Ok(shapes)
    }
}
impl WorldGeometry {
    pub fn refresh_structure_collision(&mut self, st: &Structure) -> Result<(), &'static str> {
        if self.pending_removals().contains(&st.id) {
            return Err("cannot refresh retired structure collision");
        }
        let shapes = st.collision_shapes()?;
        let id = i64::from(st.id);
        if !st.built {
            self.collision.remove(id);
        } else if (!shapes.is_empty() || self.collision.contains(id))
            && !self.collision.replace(id, &shapes)
        {
            return Err("structure collision exceeds world limits");
        }
        Ok(())
    }
}

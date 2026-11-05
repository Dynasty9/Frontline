//! Buildings and battlefield debris acquire their gameplay geometry without scene nodes.
use crate::cover;
use crate::structure::{Part, Structure};
use crate::vector::Vector3;
use glam::Vec2;

#[derive(Clone, Copy, Debug)]
pub struct BuildingProfile {
    pub size: [f32; 2],
    pub hp: f64,
}

fn v(p: [f64; 3]) -> Vector3 {
    Vector3::new(p[0] as f32, p[1] as f32, p[2] as f32)
}
fn part(
    position: [f64; 3],
    size: [f64; 3],
    infantry: u8,
    vehicle: u8,
    cover: bool,
    collision: bool,
) -> Part {
    Part {
        position: v(position),
        size: v(size),
        yaw: 0.0,
        infantry,
        vehicle,
        cover,
        collision,
        door: false,
    }
}

impl Structure {
    /// Definition values are immutable match content, rather than callbacks into the renderer.
    pub fn initialize(
        &mut self,
        profile: Option<BuildingProfile>,
        map_half: f64,
    ) -> Result<(), &'static str> {
        if self.gone
            || !self.nav_cells.is_empty()
            || !self.hash_cells.is_empty()
            || profile.is_some_and(|p| {
                !p.hp.is_finite()
                    || !(0.0..=1e12).contains(&p.hp)
                    || p.size
                        .iter()
                        .any(|v| !v.is_finite() || !(0.0..=8192.0).contains(v))
            })
        {
            return Err("invalid new structure");
        }
        let mut st = self.clone();
        if st.size == Vector3::ONE {
            st.size = if let Some(p) = profile {
                Vector3::new(p.size[0], 3.0, p.size[1])
            } else {
                match st.kind.as_str() {
                    "depot" => v([17.0, 3.0, 11.0]),
                    "wreck" => v([3.4, 2.0, 6.2]),
                    "car" => v([1.8, 1.5, 4.2]),
                    "crates" => v([if st.variant == 1 { 2.5 } else { 1.2 }, 1.2, 1.25]),
                    "tree" => v([0.6, 5.0, 0.6]),
                    "town" => v([3.6, 2.0, 2.4]),
                    _ => st.size,
                }
            };
        }
        st.parts = st.define_parts();
        let mut foot = Vec2::new(st.size.x * 0.5, st.size.z * 0.5);
        if st.kind == "trench" {
            foot.x = (f64::from(foot.x) + 0.72) as f32;
        }
        st.footprint = foot.to_array();
        st.radius = f64::from(foot.length()) + 0.5;
        st.indestructible = matches!(st.kind.as_str(), "depot" | "floor" | "bridge" | "town");
        st.smashable = matches!(
            st.kind.as_str(),
            "low_wall"
                | "tall_wall"
                | "house_wall"
                | "crates"
                | "car"
                | "tree"
                | "sandbags"
                | "concrete_wall"
                | "wire"
                | "rubble"
                | "fence"
                | "barricade"
        );
        if st.max_hp <= 0.0 || st.hp == 100.0 && st.max_hp == 100.0 {
            st.max_hp = profile.map_or_else(
                || match st.kind.as_str() {
                    "low_wall" => 260.0 * f64::from(st.size.x) / 4.0,
                    "tall_wall" | "house_wall" => 600.0 * f64::from(st.size.x) / 4.0,
                    "bridge" | "depot" => 99999.0,
                    "crates" => 200.0,
                    "car" => 300.0,
                    "wreck" => 5000.0,
                    "tree" => 400.0,
                    "rubble" => 2000.0,
                    "roof" => 450.0,
                    _ => 300.0,
                },
                |p| p.hp,
            );
            st.hp = st.max_hp * if st.built { 1.0 } else { 0.1 };
        }
        if st.kind == "ammo_cache" && st.supply <= 0.0 {
            st.supply = 160.0;
        }
        st.refresh_anchors(map_half)?;
        if !st.valid()
            || st
                .parts
                .iter()
                .any(|p| p.collision && p.size.min_element() <= 0.0)
        {
            return Err("invalid generated structure");
        }
        *self = st;
        Ok(())
    }

    pub fn refresh_anchors(&mut self, map_half: f64) -> Result<(), &'static str> {
        let parts: Vec<_> = self
            .parts
            .iter()
            .map(|p| cover::Part {
                position: p.position,
                size: p.size,
                yaw: p.yaw,
                cover: p.cover,
                collision: p.collision,
                blocks_navigation: p.infantry != 0,
            })
            .collect();
        let anchors = cover::generate(
            &self.kind,
            self.variant,
            self.position,
            self.yaw,
            self.size,
            &parts,
            map_half,
        )?;
        self.cover_points = anchors.iter().map(|a| a.position).collect();
        self.anchors = anchors;
        Ok(())
    }

    fn define_parts(&self) -> Vec<Part> {
        let [l, y, z] = self.size.to_array().map(f64::from);
        let mut parts = vec![];
        let mut add = |p, s, i, veh, cover, col| parts.push(part(p, s, i, veh, cover, col));
        match self.kind.as_str() {
            "low_wall" => {
                let h = if self.variant % 3 == 1 {
                    1.15
                } else if y > 0.2 {
                    y
                } else {
                    1.0
                };
                add(
                    [0.0, h * 0.5, 0.0],
                    [l, h, if self.variant % 3 == 1 { 0.9 } else { 0.5 }],
                    1,
                    1,
                    true,
                    true,
                );
            }
            "tall_wall" => add([0.0, 1.3, 0.0], [l, 2.6, 0.5], 3, 1, true, true),
            "house_wall" => match self.variant {
                1 | 2 => {
                    let w = if self.variant == 1 { 1.3 } else { 1.9 };
                    let pier = (l - w) * 0.5;
                    add(
                        [-l * 0.5 + pier * 0.5, 1.5, 0.0],
                        [pier, 3.0, 0.4],
                        3,
                        1,
                        true,
                        true,
                    );
                    add(
                        [l * 0.5 - pier * 0.5, 1.5, 0.0],
                        [pier, 3.0, 0.4],
                        3,
                        1,
                        true,
                        true,
                    );
                    if self.variant == 1 {
                        add([0.0, 0.5, 0.0], [w, 1.0, 0.4], 1, 1, true, true);
                        add([0.0, 2.5, 0.0], [w, 1.0, 0.4], 0, 0, false, true);
                    } else {
                        add([0.0, 2.6, 0.0], [w, 0.8, 0.4], 0, 0, false, true);
                        if self.door_closed {
                            add([0.0, 1.05, 0.08], [w, 2.1, 0.08], 0, 0, false, true);
                            parts.last_mut().unwrap().door = true;
                        }
                    }
                }
                _ => add([0.0, 1.5, 0.0], [l, 3.0, 0.4], 3, 1, true, true),
            },
            "floor" => add([0.0, 0.03, 0.0], [l, 0.06, z], 0, 0, false, false),
            "dock" => add(
                [-l * 0.5 + 2.9, 1.85, 0.35],
                [4.9, 3.7, z - 1.3],
                3,
                3,
                true,
                true,
            ),
            "bridge" => {
                add([0.0, -0.25, 0.0], [l, 0.5, z], 0, 0, false, true);
                if self.variant == 0 {
                    for sx in [-1.0, 1.0] {
                        add(
                            [sx * (l * 0.5 - 0.18), 0.45, 0.0],
                            [0.36, 0.9, z - 1.0],
                            3,
                            3,
                            true,
                            true,
                        );
                    }
                }
            }
            "rubble" => {
                add([0.0, 0.35, 0.0], [l, 0.7, z.max(1.0)], 1, 0, true, true);
                add([l * 0.15, 0.6, 0.1], [l * 0.45, 1.0, 0.8], 1, 0, true, true);
                parts[1].yaw = 0.3;
            }
            "crates" if self.variant == 0 => {
                add([0.0, 0.6, 0.0], [1.2, 1.2, 1.2], 1, 1, true, true)
            }
            "crates" => {
                add([0.0, 0.6, 0.0], [2.5, 1.2, 1.25], 3, 1, true, true);
                add([-0.6, 1.8, 0.0], [1.2, 1.2, 1.2], 0, 0, false, true);
                parts[1].yaw = 0.15;
            }
            "car" => {
                add([0.0, 0.55, 0.0], [1.8, 0.8, 4.2], 3, 1, true, true);
                add([0.0, 1.18, 0.25], [1.6, 0.5, 2.1], 0, 0, false, true);
            }
            "wreck" => {
                add([0.0, y * 0.375, 0.0], [l, y * 0.75, z], 3, 3, true, true);
                add(
                    [0.0, y * 0.92, z * 0.05],
                    [l * 0.65, y * 0.35, z * 0.42],
                    0,
                    0,
                    false,
                    true,
                );
                parts[1].yaw = 0.4;
            }
            "tree" => add([0.0, 2.5, 0.0], [0.5, 5.0, 0.5], 3, 1, true, true),
            "fob" => {
                add([0.0, 1.2, 0.0], [4.6, 2.4, 4.6], 3, 3, true, true);
                for s in [-1.0, 1.0] {
                    for side in [-1.0, 1.0] {
                        add(
                            [side * 4.0, 0.5, s * 6.3],
                            [4.6, 1.0, 0.9],
                            1,
                            1,
                            true,
                            true,
                        );
                        add(
                            [s * 6.3, 0.5, side * 4.0],
                            [0.9, 1.0, 4.6],
                            1,
                            1,
                            true,
                            true,
                        );
                    }
                }
            }
            "town" => {
                add([0.55, 0.62, 0.35], [2.3, 1.24, 1.4], 3, 3, true, true);
                add([0.85, 1.7, 0.4], [1.3, 0.9, 1.1], 0, 0, false, true);
                add([-1.15, 0.45, 0.2], [1.2, 0.9, 1.7], 3, 3, true, true);
            }
            "barracks" => add([0.0, 1.5, 0.0], [l, 3.0, z], 3, 3, true, true),
            "factory" => add([0.0, 2.5, 0.0], [l, 5.0, z], 3, 3, true, true),
            "medic_tent" => add([0.0, 1.3, 0.0], [l, 2.6, z], 3, 3, true, true),
            "research" => add([0.0, 1.6, 0.0], [l, 3.2, z], 3, 3, true, true),
            "depot" => {
                add([-5.0, 1.3, 0.0], [6.0, 2.6, 2.5], 3, 3, true, true);
                add([5.0, 1.3, -1.0], [6.0, 2.6, 2.5], 3, 3, true, true);
                add([0.0, 1.5, 3.5], [5.0, 3.0, 4.0], 3, 3, true, true);
            }
            "sandbags" => add([0.0, 0.5, 0.0], [l, 1.0, 0.9], 1, 1, true, true),
            "concrete_wall" => add([0.0, 1.3, 0.0], [l, 2.6, 0.6], 3, 1, true, true),
            "hesco" => add([0.0, 0.685, 0.0], [l, 1.37, 1.06], 1, 3, true, true),
            "barricade" => add([0.0, 0.6, 0.0], [l, 1.2, 0.9], 1, 1, true, true),
            "ammo_cache" => {
                add([0.0, 0.6, 0.15], [2.5, 1.2, 1.1], 3, 3, true, true);
                add([0.0, 0.2, -0.95], [2.6, 0.4, 0.42], 1, 1, false, true);
            }
            "trench" => {
                add([0.0, -0.43, -1.2], [l, 1.54, 0.95], 1, 1, true, true);
                add([0.0, -0.43, 1.2], [l, 1.54, 0.95], 1, 1, true, true);
            }
            "wire" => add([0.0, 0.45, 0.0], [l, 0.9, 1.2], 2, 0, false, false),
            "tank_trap" => add([0.0, 0.6, 0.0], [1.8, 1.2, 1.8], 0, 3, false, false),
            "mg_nest" | "hmg_nest" if self.variant == 1 => {
                let z = -(0.72 + 1.0);
                add([0.0, 0.15, z], [2.2, 0.3, 0.6], 1, 1, true, true);
                add([-0.95, 0.15, z + 0.55], [0.5, 0.3, 0.6], 1, 1, true, true);
                add([0.95, 0.15, z + 0.55], [0.5, 0.3, 0.6], 1, 1, true, true);
            }
            "mg_nest" => {
                add([0.0, 0.43, -1.7], [3.8, 0.86, 0.8], 1, 1, true, true);
                add([-1.7, 0.5, -0.4], [0.8, 1.0, 2.0], 1, 1, true, true);
                add([1.7, 0.5, -0.4], [0.8, 1.0, 2.0], 1, 1, true, true);
            }
            "hmg_nest" => {
                add([0.0, 0.44, -1.85], [4.2, 0.88, 0.9], 1, 1, true, true);
                add([-1.85, 0.55, -0.5], [0.9, 1.1, 1.9], 1, 1, true, true);
                add([1.85, 0.55, -0.5], [0.9, 1.1, 1.9], 1, 1, true, true);
            }
            "watchtower" => {
                for x in [-1.2, 1.2] {
                    for z in [-1.2, 1.2] {
                        add([x, 2.1, z], [0.25, 4.2, 0.25], 3, 1, false, false);
                    }
                }
                add([0.0, 4.1, 0.0], [3.0, 0.25, 3.0], 0, 0, false, true);
                add([0.0, 4.7, -1.45], [3.0, 0.95, 0.15], 0, 0, false, true);
                add([0.0, 4.7, 1.45], [3.0, 0.95, 0.15], 0, 0, false, true);
                add([-1.45, 4.7, 0.0], [0.15, 0.95, 3.0], 0, 0, false, true);
                add([1.45, 4.7, 0.0], [0.15, 0.95, 3.0], 0, 0, false, true);
            }
            "mortar_pit" => {
                for i in 0..5 {
                    let a =
                        -std::f64::consts::PI * 0.75 + f64::from(i) * std::f64::consts::PI * 0.375;
                    let c = v([libm::sin(a), 0.0, -libm::cos(a)]) * 2.0;
                    let mut p = part(
                        [f64::from(c.x), 0.4, f64::from(c.z)],
                        [1.7, 0.8, 0.8],
                        1,
                        1,
                        true,
                        true,
                    );
                    p.yaw = -a;
                    parts.push(p);
                }
            }
            "at_post" => {
                add([0.0, 0.45, -1.5], [3.6, 0.9, 0.8], 1, 1, true, true);
                add([-1.6, 0.45, -0.5], [0.7, 0.9, 1.4], 1, 1, true, true);
            }
            "bunker" => {
                let h = 2.2;
                let t = 0.6;
                let hz = 2.8 - t * 0.5;
                add([-2.05, h * 0.5, -hz], [1.5, h, t], 3, 3, true, true);
                add([2.05, h * 0.5, -hz], [1.5, h, t], 3, 3, true, true);
                add([0.0, 0.55, -hz], [2.6, 1.1, t], 3, 3, true, true);
                add([0.0, 1.925, -hz], [2.6, 0.55, t], 0, 0, false, true);
                for sx in [-1.0, 1.0] {
                    add([sx * hz, h * 0.5, -1.55], [t, h, 1.3], 3, 3, true, true);
                    add([sx * hz, h * 0.5, 1.55], [t, h, 1.3], 3, 3, true, true);
                    add([sx * hz, 0.55, 0.0], [t, 1.1, 1.8], 3, 3, true, true);
                    add([sx * hz, 1.925, 0.0], [t, 0.55, 1.8], 0, 0, false, true);
                }
                add([-1.9, h * 0.5, hz], [1.8, h, t], 3, 3, true, true);
                add([1.9, h * 0.5, hz], [1.8, h, t], 3, 3, true, true);
                add([0.0, 2.05, hz], [2.0, 0.3, t], 0, 0, false, true);
                add([0.0, h + 0.18, 0.0], [5.8, 0.36, 5.8], 0, 0, false, true);
            }
            _ => {}
        }
        parts
    }
}

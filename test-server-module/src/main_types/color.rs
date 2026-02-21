use spacetimedb::{rand::Rng, ReducerContext, SpacetimeType};

#[derive(SpacetimeType, Debug, Clone, Copy)]
pub struct Color {
    pub r: f32,
    pub g: f32,
    pub b: f32,
    pub a: f32,
}

impl Color {
    pub fn new(r: f32, g: f32, b: f32, a: f32) -> Color {
        Color { r, g, b, a }
    }

    pub fn random(ctx: &ReducerContext) -> Color {
        let r = ctx.rng().gen_range(0.0..1.0);
        let g = ctx.rng().gen_range(0.0..1.0);
        let b = ctx.rng().gen_range(0.0..1.0);

        Color::new(r, g, b, 1.0)
    }
}

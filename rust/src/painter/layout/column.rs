use super::container::{ContainerSpec, StackDirection};

#[derive(Debug, Clone)]
pub struct ColumnSpec {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
    pub containers: Vec<(ContainerSpec, StackDirection)>,
}

impl ColumnSpec {
    pub fn new(x: f32, y: f32, width: f32, height: f32) -> Self {
        Self {
            x,
            y,
            width,
            height,
            containers: Vec::new(),
        }
    }

    pub fn add_container(
        &mut self,
        spec: ContainerSpec,
        direction: StackDirection,
    ) -> &mut Self {
        self.containers.push((spec, direction));
        self
    }
}

#[derive(Debug, Clone)]
pub struct PageSpec {
    pub columns: Vec<ColumnSpec>,
}

impl PageSpec {
    pub fn new() -> Self {
        Self {
            columns: Vec::new(),
        }
    }

    pub fn add_column(&mut self, column: ColumnSpec) -> &mut Self {
        self.columns.push(column);
        self
    }

    pub fn single_column(width: f32, height: f32) -> Self {
        Self {
            columns: vec![ColumnSpec::new(0.0, 0.0, width, height)],
        }
    }
}

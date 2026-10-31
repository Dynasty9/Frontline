use crate::vector::Vector3;

pub(crate) fn header(schema: &[u8; 8]) -> [u8; 8] {
    let mut header = *schema;
    header[6..8].copy_from_slice(&crate::NUMERIC_VERSION.to_le_bytes());
    header
}

pub(crate) struct Writer(pub Vec<u8>);

impl Writer {
    pub fn new(schema: &[u8; 8]) -> Self {
        Self(header(schema).to_vec())
    }
    pub fn byte(&mut self, value: u8) {
        self.0.push(value);
    }
    pub fn u32(&mut self, value: u32) {
        self.0.extend_from_slice(&value.to_le_bytes());
    }
    pub fn u64(&mut self, value: u64) {
        self.0.extend_from_slice(&value.to_le_bytes());
    }
    pub fn f64(&mut self, value: f64) {
        self.0.extend_from_slice(&value.to_le_bytes());
    }
    pub fn f32(&mut self, value: f32) {
        self.0.extend_from_slice(&value.to_le_bytes());
    }
    pub fn bytes(&mut self, value: &[u8]) {
        self.u32(value.len() as u32);
        self.0.extend_from_slice(value);
    }
    pub fn point(&mut self, value: Vector3) {
        for value in value.to_array() {
            self.0.extend_from_slice(&value.to_le_bytes());
        }
    }
}

pub(crate) struct Reader<'a>(&'a [u8]);

impl<'a> Reader<'a> {
    pub fn new(bytes: &'a [u8], schema: &[u8; 8]) -> Result<Self, &'static str> {
        bytes
            .strip_prefix(&header(schema))
            .map(Self)
            .ok_or("incompatible checkpoint version")
    }
    fn take<const N: usize>(&mut self) -> Result<[u8; N], &'static str> {
        let (head, tail) = self.0.split_at_checked(N).ok_or("truncated checkpoint")?;
        self.0 = tail;
        Ok(head.try_into().unwrap())
    }
    pub fn byte(&mut self) -> Result<u8, &'static str> {
        Ok(self.take::<1>()?[0])
    }
    pub fn boolean(&mut self) -> Result<bool, &'static str> {
        match self.byte()? {
            0 => Ok(false),
            1 => Ok(true),
            _ => Err("invalid checkpoint flag"),
        }
    }
    pub fn u32(&mut self) -> Result<u32, &'static str> {
        Ok(u32::from_le_bytes(self.take()?))
    }
    pub fn u64(&mut self) -> Result<u64, &'static str> {
        Ok(u64::from_le_bytes(self.take()?))
    }
    pub fn f64(&mut self) -> Result<f64, &'static str> {
        let value = f64::from_le_bytes(self.take()?);
        if value.is_finite() {
            Ok(value)
        } else {
            Err("nonfinite checkpoint value")
        }
    }
    pub fn f32(&mut self) -> Result<f32, &'static str> {
        let value = f32::from_le_bytes(self.take()?);
        if value.is_finite() {
            Ok(value)
        } else {
            Err("nonfinite checkpoint value")
        }
    }
    pub fn bytes(&mut self, limit: usize) -> Result<&'a [u8], &'static str> {
        let count = self.u32()? as usize;
        if count > limit {
            return Err("checkpoint block exceeds limit");
        }
        let (head, tail) = self
            .0
            .split_at_checked(count)
            .ok_or("truncated checkpoint block")?;
        self.0 = tail;
        Ok(head)
    }
    pub fn point(&mut self) -> Result<Vector3, &'static str> {
        let value = Vector3::new(
            f32::from_le_bytes(self.take()?),
            f32::from_le_bytes(self.take()?),
            f32::from_le_bytes(self.take()?),
        );
        if value.is_finite() {
            Ok(value)
        } else {
            Err("nonfinite checkpoint point")
        }
    }
    pub fn finish(self) -> Result<(), &'static str> {
        if self.0.is_empty() {
            Ok(())
        } else {
            Err("trailing checkpoint data")
        }
    }
}

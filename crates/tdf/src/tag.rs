use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Tag([u8; 4]);

impl Tag {
    pub fn new(text: &str) -> Self {
        let mut bytes = [0u8; 4];
        for (slot, byte) in bytes.iter_mut().zip(text.bytes()) {
            *slot = byte.to_ascii_uppercase();
        }
        Self(bytes)
    }

    /// Blaze packs each character into 6 bits: bit 6 of the ASCII code, then its 5 low bits.
    pub fn to_wire(self) -> [u8; 3] {
        let packed = self.0.iter().fold(0u32, |acc, &c| {
            (acc << 6) | (((c & 0x40) >> 1) | (c & 0x1F)) as u32
        });
        let [_, a, b, c] = packed.to_be_bytes();
        [a, b, c]
    }

    pub fn from_wire(bytes: [u8; 3]) -> Self {
        let packed = u32::from_be_bytes([0, bytes[0], bytes[1], bytes[2]]);
        let mut text = [0u8; 4];
        for (index, slot) in text.iter_mut().enumerate() {
            let code = ((packed >> (18 - 6 * index)) & 0x3F) as u8;
            *slot = match code {
                0 => 0,
                _ if code & 0x20 != 0 => 0x40 | (code & 0x1F),
                _ => 0x30 | code,
            };
        }
        Self(text)
    }
}

impl fmt::Display for Tag {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let len = self.0.iter().position(|&b| b == 0).unwrap_or(4);
        f.write_str(&String::from_utf8_lossy(&self.0[..len]))
    }
}

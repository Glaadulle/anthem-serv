pub const HEADER_LEN: usize = 16;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MessageType {
    Message,
    Reply,
    Notification,
    ErrorReply,
    Ping,
    PingReply,
}

impl MessageType {
    fn from_bits(bits: u8) -> Option<Self> {
        Some(match bits {
            0 => Self::Message,
            1 => Self::Reply,
            2 => Self::Notification,
            3 => Self::ErrorReply,
            4 => Self::Ping,
            5 => Self::PingReply,
            _ => return None,
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Frame {
    pub component: u16,
    pub command: u16,
    pub msg_num: u32,
    pub msg_type: MessageType,
    pub metadata: Vec<u8>,
    pub payload: Vec<u8>,
}

impl Frame {
    pub fn encode(&self) -> Vec<u8> {
        let mut out = Vec::with_capacity(HEADER_LEN + self.metadata.len() + self.payload.len());
        out.extend_from_slice(&(self.payload.len() as u32).to_be_bytes());
        out.extend_from_slice(&(self.metadata.len() as u16).to_be_bytes());
        out.extend_from_slice(&self.component.to_be_bytes());
        out.extend_from_slice(&self.command.to_be_bytes());
        out.extend_from_slice(&self.msg_num.to_be_bytes()[1..]);
        out.push((self.msg_type as u8) << 5);
        out.extend_from_slice(&[0, 0]);
        out.extend_from_slice(&self.metadata);
        out.extend_from_slice(&self.payload);
        out
    }

    pub fn decode(bytes: &[u8]) -> Option<(Self, usize)> {
        let header = bytes.get(..HEADER_LEN)?;
        let payload_len = u32::from_be_bytes(header[0..4].try_into().ok()?) as usize;
        let metadata_len = u16::from_be_bytes([header[4], header[5]]) as usize;
        let total = HEADER_LEN + metadata_len + payload_len;
        let body = bytes.get(HEADER_LEN..total)?;
        let frame = Self {
            component: u16::from_be_bytes([header[6], header[7]]),
            command: u16::from_be_bytes([header[8], header[9]]),
            msg_num: u32::from_be_bytes([0, header[10], header[11], header[12]]),
            msg_type: MessageType::from_bits(header[13] >> 5)?,
            metadata: body[..metadata_len].to_vec(),
            payload: body[metadata_len..].to_vec(),
        };
        Some((frame, total))
    }

    pub fn notification(component: u16, command: u16, payload: Vec<u8>) -> Self {
        Self {
            component,
            command,
            msg_num: 0,
            msg_type: MessageType::Notification,
            metadata: Vec::new(),
            payload,
        }
    }

    pub fn reply(&self, payload: Vec<u8>) -> Self {
        Self {
            msg_type: MessageType::Reply,
            metadata: Vec::new(),
            payload,
            ..self.clone()
        }
    }
}

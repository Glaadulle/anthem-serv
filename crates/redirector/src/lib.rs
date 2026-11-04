pub mod http;

pub struct ServerInstanceRequest {
    pub service_name: String,
    pub client_version: String,
    pub connection_profile: String,
}

impl ServerInstanceRequest {
    pub fn parse(xml: &str) -> Option<Self> {
        Some(Self {
            service_name: element_text(xml, "name")?,
            client_version: element_text(xml, "clientversion").unwrap_or_default(),
            connection_profile: element_text(xml, "connectionprofile").unwrap_or_default(),
        })
    }
}

fn element_text(xml: &str, name: &str) -> Option<String> {
    let open = format!("<{name}>");
    let start = xml.find(&open)? + open.len();
    let end = start + xml[start..].find(&format!("</{name}>"))?;
    Some(xml[start..end].trim().to_owned())
}

pub struct BlazeEndpoint {
    pub hostname: String,
    pub ip: [u8; 4],
    pub port: u16,
    pub secure: bool,
}

pub fn render_server_instance(endpoint: &BlazeEndpoint) -> String {
    format!(
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
         <serverinstanceinfo>\n\
         \x20 <address member=\"0\">\n\
         \x20   <valu>\n\
         \x20     <hostname>{hostname}</hostname>\n\
         \x20     <ip>{ip}</ip>\n\
         \x20     <port>{port}</port>\n\
         \x20   </valu>\n\
         \x20 </address>\n\
         \x20 <secure>{secure}</secure>\n\
         \x20 <trialservicename></trialservicename>\n\
         \x20 <defaultdnsaddress>0</defaultdnsaddress>\n\
         </serverinstanceinfo>\n",
        hostname = endpoint.hostname,
        ip = u32::from_be_bytes(endpoint.ip),
        port = endpoint.port,
        secure = u8::from(endpoint.secure),
    )
}

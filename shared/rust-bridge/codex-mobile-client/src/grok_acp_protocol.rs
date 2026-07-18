//! Newline-delimited JSON-RPC framing for Grok Build's ACP server.

use serde_json::Value;

#[derive(Debug, Clone, PartialEq)]
pub(crate) enum GrokAcpMessage {
    Response {
        id: Value,
        result: Option<Value>,
        error: Option<Value>,
    },
    Notification {
        method: String,
        params: Value,
    },
    Request {
        id: Value,
        method: String,
        params: Value,
    },
}

#[derive(Default)]
pub(crate) struct GrokAcpLineDecoder {
    pending: Vec<u8>,
}

impl GrokAcpLineDecoder {
    pub(crate) fn push(&mut self, bytes: &[u8]) -> Result<Vec<GrokAcpMessage>, String> {
        self.pending.extend_from_slice(bytes);
        let mut messages = Vec::new();

        while let Some(index) = self.pending.iter().position(|byte| *byte == b'\n') {
            let line: Vec<u8> = self.pending.drain(..=index).collect();
            let line = line[..line.len() - 1]
                .strip_suffix(b"\r")
                .unwrap_or(&line[..line.len() - 1]);
            if line.iter().all(u8::is_ascii_whitespace) {
                continue;
            }
            let value: Value = serde_json::from_slice(line)
                .map_err(|error| format!("invalid Grok ACP JSON: {error}"))?;
            messages.push(classify(value)?);
        }

        Ok(messages)
    }
}

pub(crate) fn request_line(id: u64, method: &str, params: Value) -> Result<String, String> {
    serde_json::to_string(&serde_json::json!({
        "jsonrpc": "2.0",
        "id": id,
        "method": method,
        "params": params,
    }))
    .map_err(|error| format!("encode Grok ACP request: {error}"))
}

pub(crate) fn response_line(id: Value, result: Value) -> Result<String, String> {
    serde_json::to_string(&serde_json::json!({
        "jsonrpc": "2.0",
        "id": id,
        "result": result,
    }))
    .map_err(|error| format!("encode Grok ACP response: {error}"))
}

fn classify(value: Value) -> Result<GrokAcpMessage, String> {
    let object = value
        .as_object()
        .ok_or_else(|| "Grok ACP message is not an object".to_string())?;
    if object.get("jsonrpc").and_then(Value::as_str) != Some("2.0") {
        return Err("Grok ACP message has an invalid jsonrpc version".to_string());
    }

    let id = object.get("id").cloned();
    let method = object
        .get("method")
        .and_then(Value::as_str)
        .map(str::to_string);
    let params = object.get("params").cloned().unwrap_or(Value::Null);

    match (id, method) {
        (Some(id), Some(method)) => Ok(GrokAcpMessage::Request { id, method, params }),
        (None, Some(method)) => Ok(GrokAcpMessage::Notification { method, params }),
        (Some(id), None) => Ok(GrokAcpMessage::Response {
            id,
            result: object.get("result").cloned(),
            error: object.get("error").cloned(),
        }),
        (None, None) => Err("Grok ACP message has neither id nor method".to_string()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn decodes_fragmented_and_batched_messages() {
        let mut decoder = GrokAcpLineDecoder::default();
        assert!(decoder.push(br#"{"jsonrpc":"2.0","id":1,"res"#).unwrap().is_empty());

        let messages = decoder
            .push(
                b"ult\":{\"ok\":true}}\n\
                  {\"jsonrpc\":\"2.0\",\"method\":\"session/update\",\"params\":{\"update\":{\"sessionUpdate\":\"agent_message_chunk\"}}}\n",
            )
            .unwrap();

        assert_eq!(messages.len(), 2);
        assert!(matches!(messages[0], GrokAcpMessage::Response { .. }));
        assert!(matches!(
            messages[1],
            GrokAcpMessage::Notification { ref method, .. } if method == "session/update"
        ));
    }

    #[test]
    fn distinguishes_agent_requests() {
        let mut decoder = GrokAcpLineDecoder::default();
        let messages = decoder
            .push(
                br#"{"jsonrpc":"2.0","id":"permission-1","method":"session/request_permission","params":{}}"#,
            )
            .unwrap();
        assert!(messages.is_empty());
        let messages = decoder.push(b"\n").unwrap();
        assert!(matches!(
            messages[0],
            GrokAcpMessage::Request { ref method, .. }
                if method == "session/request_permission"
        ));
    }
}

//! Persistent Grok Build ACP process hosted inside Litter's embedded iSH.

use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;

use ish_embed_host::{IshSession, SpawnOpts, WriteStatus};

use crate::ish_runtime;

const START_TIMEOUT: Duration = Duration::from_secs(15);
const IO_CHUNK_BYTES: usize = 256 * 1024;

pub(crate) struct GrokAcpProcess {
    session: Arc<IshSession>,
    next_sequence: u64,
}

impl GrokAcpProcess {
    pub(crate) async fn spawn(cwd: impl Into<PathBuf>, api_key: &str) -> Result<Self, String> {
        let instance = ish_runtime::instance_or_wait(START_TIMEOUT)
            .await
            .ok_or_else(|| "iSH runtime is not ready".to_string())?;
        let mut env = ish_runtime::runtime_env();
        env.insert("XAI_API_KEY".to_string(), api_key.to_string());
        env.insert("NO_COLOR".to_string(), "1".to_string());

        let session = instance
            .spawn(SpawnOpts {
                argv: vec![
                    "/usr/local/bin/grok".to_string(),
                    "agent".to_string(),
                    "stdio".to_string(),
                ],
                envp: Some(env.into_iter().collect()),
                cwd: Some(cwd.into()),
                tty: false,
                size: None,
                pipe_stdin: true,
                arg0: None,
            })
            .map_err(|error| format!("spawn Grok ACP agent: {error}"))?;

        let process = Self {
            session,
            next_sequence: 0,
        };
        process.wait_until_writable().await?;
        Ok(process)
    }

    pub(crate) async fn send_json_line(&self, json: &str) -> Result<(), String> {
        if json.as_bytes().contains(&b'\n') {
            return Err("ACP request must be one JSON line".to_string());
        }
        let mut payload = Vec::with_capacity(json.len() + 1);
        payload.extend_from_slice(json.as_bytes());
        payload.push(b'\n');
        match self
            .session
            .write(&payload)
            .await
            .map_err(|error| format!("write Grok ACP stdin: {error}"))?
        {
            WriteStatus::Accepted => Ok(()),
            WriteStatus::Starting => Err("Grok ACP agent is still starting".to_string()),
            WriteStatus::StdinClosed => Err("Grok ACP stdin is closed".to_string()),
        }
    }

    pub(crate) async fn read_available(&mut self, wait: Duration) -> Result<Vec<u8>, String> {
        let output = self
            .session
            .read(
                Some(self.next_sequence),
                Some(IO_CHUNK_BYTES),
                Some(u64::try_from(wait.as_millis()).unwrap_or(u64::MAX)),
            )
            .await
            .map_err(|error| format!("read Grok ACP stdout: {error}"))?;

        let mut bytes = Vec::new();
        for chunk in output.chunks {
            self.next_sequence = self.next_sequence.max(chunk.seq);
            bytes.extend_from_slice(&chunk.bytes);
        }
        if output.closed && bytes.is_empty() {
            return Err(format!(
                "Grok ACP agent exited with code {}",
                output.exit_code.unwrap_or(-1)
            ));
        }
        Ok(bytes)
    }

    pub(crate) async fn terminate(&self) -> Result<(), String> {
        self.session
            .terminate()
            .await
            .map_err(|error| format!("terminate Grok ACP agent: {error}"))
    }

    async fn wait_until_writable(&self) -> Result<(), String> {
        let deadline = tokio::time::Instant::now() + START_TIMEOUT;
        loop {
            match self
                .session
                .write(&[])
                .await
                .map_err(|error| format!("probe Grok ACP stdin: {error}"))?
            {
                WriteStatus::Accepted => return Ok(()),
                WriteStatus::StdinClosed => {
                    return Err("Grok ACP agent exited during startup".to_string());
                }
                WriteStatus::Starting if tokio::time::Instant::now() < deadline => {
                    tokio::time::sleep(Duration::from_millis(25)).await;
                }
                WriteStatus::Starting => {
                    return Err("timed out starting Grok ACP agent".to_string());
                }
            }
        }
    }
}

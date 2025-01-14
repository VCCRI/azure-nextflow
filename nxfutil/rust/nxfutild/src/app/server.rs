#[derive(Clone)]
pub struct AppServer {
    variables: AppVariables,
    secrets: AppSecrets,
    az_identity: AppAzIdentity,
    az_storage_queues: AppAzStorageQueues
}

impl AppServer {
    fn new(variables: AppVariables, secrets: AppSecrets, az_identity: AppAzIdentity) -> Self {
        Self {
            az_storage_queues: AppAzStorageQueues::new(az_identity.credential.clone(), &variables, &secrets),
            az_identity: az_identity,
            variables: variables,
            secrets: secrets
        }
    }
    async fn init(server: &AppServer) {
        match server.az_storage_queues.queue_client.create().await {
            Ok(_) => {
                println!("[nxfutild][az-storage-queues] Creating queue if not exists {:#?}...Ok", server.variables.q_name);
            },
            Err(error) => {
                println!("[nxfutild][az-storage-queues] Creating queue if not exists {:#?}...Err", server.variables.q_name);
                panic!("{}", error)
            }
        }
    }
    async fn send_message_to_queue(Json(req_payload): Json<Value>, server: &AppServer) {
        if !(req_payload["event"] == "started") && !(req_payload["event"] == "completed") {
            println!("[nxfutild][az-storage-queues] Ignoring message {:#?}", req_payload["event"]);
            return
        }
        match server.az_storage_queues.queue_client.put_message(req_payload.to_string()).await {
            Ok(_) => {
                println!("[nxfutild][az-storage-queues] Sending message {:#?}...Ok", req_payload["event"]);
            },
            Err(error) => {
                println!("[nxfutild][az-storage-queues] Sending message {:#?}...Err", req_payload["event"]);
                println!("[nxfutild]{}", error)
            }        
        }
    }
}
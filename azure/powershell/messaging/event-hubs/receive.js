const { EventHubConsumerClient } = require('@azure/event-hubs');
const { ContainerClient } = require('@azure/storage-blob');
const {
  BlobCheckpointStore,
} = require('@azure/eventhubs-checkpointstore-blob');

const connectionString = process.env.varEventHubNamespaceConnection;
const eventHubName = process.env.varEventHubName;
const consumerGroup = '$Default'; // name of the default consumer group
const storageConnectionString = process.env.varStorageConnectionString;
const containerName = process.env.varContainerName;

async function main() {
  // Create a blob container client and a blob checkpoint store using the client.
  const containerClient = new ContainerClient(
    storageConnectionString,
    containerName
  );
  const checkpointStore = new BlobCheckpointStore(containerClient);

  // Create a consumer client for the event hub by specifying the checkpoint store.
  const consumerClient = new EventHubConsumerClient(
    consumerGroup,
    connectionString,
    eventHubName,
    checkpointStore
  );

  // Subscribe to the events, and specify handlers for processing the events and errors.
  const subscription = consumerClient.subscribe({
    processEvents: async (events, context) => {
      for (const event of events) {
        console.log(
          `Received event: '${event.body}' from partition: '${context.partitionId}' and consumer group: '${context.consumerGroup}'`
        );
      }
      // Update the checkpoint.
      await context.updateCheckpoint(events[events.length - 1]);
    },

    processError: async (err, context) => {
      console.log(`Error : ${err}`);
    },
  });

  // After 30 seconds, stop processing.
  await new Promise((resolve) => {
    setTimeout(async () => {
      await subscription.close();
      await consumerClient.close();
      resolve();
    }, 30000);
  });
}

main().catch((err) => {
  console.log('Error occurred: ', err);
});

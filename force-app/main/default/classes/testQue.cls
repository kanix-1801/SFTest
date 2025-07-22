public class UpdateAssetParentQueueable implements Queueable {
    private List<Id> assetIds;
    private Integer retryCount;

    public UpdateAssetParentQueueable(List<Id> assetIds, Integer retryCount) {
        this.assetIds = assetIds;
        this.retryCount = retryCount;
    }

    public void execute(QueueableContext context) {
        List<Asset> freshAssets = [SELECT Id, Name, ParentId, SBQQ__RootId__c, SBQQ__RequiredByProduct__c 
                                   FROM Asset 
                                   WHERE Id IN :assetIds];

        List<Asset> assetsToUpdate = new List<Asset>();

        for (Asset a : freshAssets) {
            if (a.SBQQ__RequiredByProduct__c != null && a.SBQQ__RootId__c != null) {
                assetsToUpdate.add(new Asset(
                    Id = a.Id,
                    ParentId = a.SBQQ__RootId__c
                ));
            }
        }

        if (!assetsToUpdate.isEmpty()) {
            update assetsToUpdate;
            System.debug('Updated Assets: ' + assetsToUpdate);
        } else if (retryCount < 5) {
            System.debug(' Retrying - SBQQ__RootId__c still not available.');
            System.enqueueJob(new UpdateAssetParentQueueable(assetIds, retryCount + 1));
        } else {
            System.debug(' Max retry reached. Some assets did not receive SBQQ__RootId__c.');
        }
    }
}

module VCAP::CloudController
  module Jobs
    module Runtime
      class OrphanedBlobsCleanup < VCAP::CloudController::Jobs::CCJob
        DIRTY_THRESHOLD = 3
        NUMBER_OF_BLOBS_TO_DELETE = 100

        def perform
          blobstores.each do |blobstore|
            blobstore.files.each do |blob|
              orphaned_blob = OrphanedBlob.find(blob_key: blob.key)
              if blob_in_use(blob)
                if orphaned_blob.present?
                  orphaned_blob.delete
                end

                next
              end

              create_or_update_orphaned_blob(blob, orphaned_blob)
            end
          end

          delete_orphaned_blobs
        end

        def max_attempts
          1
        end

        private

        def blobstores
          config = Config.config

          {
            config.dig(:droplets, :droplet_directory_key)     => CloudController::DependencyLocator.instance.droplet_blobstore,
            config.dig(:packages, :app_package_directory_key) => CloudController::DependencyLocator.instance.package_blobstore,
            config.dig(:buildpacks, :buildpack_directory_key) => CloudController::DependencyLocator.instance.buildpack_blobstore,
          }.values
        end

        def logger
          @logger ||= Steno.logger('cc.background')
        end

        def blob_in_use(blob)
          parts = blob.key.split('/')
          basename = parts[-1]
          potential_droplet_guid = parts[-2]

          blob.key.start_with?(CloudController::DependencyLocator::BUILDPACK_CACHE_DIR, CloudController::DependencyLocator::RESOURCE_POOL_DIR) ||
            DropletModel.find(guid: potential_droplet_guid, droplet_hash: basename).present? ||
            PackageModel.find(guid: basename).present? ||
            Buildpack.find(key: basename).present?
        end

        def create_or_update_orphaned_blob(blob, orphaned_blob)
          if orphaned_blob.present?
            orphaned_blob.update(dirty_count: Sequel.+(:dirty_count, 1))
          else
            OrphanedBlob.create(blob_key: blob.key, dirty_count: 1)
          end
        end

        def delete_orphaned_blobs
          dataset = OrphanedBlob.where { dirty_count >= DIRTY_THRESHOLD }.
                    order(Sequel.desc(:dirty_count)).
                    limit(NUMBER_OF_BLOBS_TO_DELETE)

          dataset.each do |orphaned_blob|
            blob_key = orphaned_blob.blob_key[6..-1]
            Jobs::Enqueuer.new(BlobstoreDelete.new(blob_key, :droplet_blobstore), queue: 'cc-generic').enqueue
            orphaned_blob.delete
          end
        end
      end
    end
  end
end

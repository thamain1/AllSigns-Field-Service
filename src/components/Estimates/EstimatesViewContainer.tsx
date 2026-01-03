import { useState } from 'react';
import { EstimatesView } from './EstimatesView';
import { NewEstimateModal } from './NewEstimateModal';
import { EstimateDetailModal } from './EstimateDetailModal';

export function EstimatesViewContainer() {
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showDetailModal, setShowDetailModal] = useState(false);
  const [selectedEstimateId, setSelectedEstimateId] = useState<string | null>(null);
  const [refreshKey, setRefreshKey] = useState(0);

  const handleCreateEstimate = () => {
    setShowCreateModal(true);
  };

  const handleViewEstimate = (estimateId: string) => {
    setSelectedEstimateId(estimateId);
    setShowDetailModal(true);
  };

  const handleSuccess = () => {
    setRefreshKey(prev => prev + 1);
  };

  return (
    <>
      <EstimatesView
        key={refreshKey}
        onViewEstimate={handleViewEstimate}
        onCreateEstimate={handleCreateEstimate}
      />
      <NewEstimateModal
        isOpen={showCreateModal}
        onClose={() => setShowCreateModal(false)}
        onSuccess={handleSuccess}
      />
      <EstimateDetailModal
        estimateId={selectedEstimateId}
        isOpen={showDetailModal}
        onClose={() => {
          setShowDetailModal(false);
          setSelectedEstimateId(null);
        }}
      />
    </>
  );
}

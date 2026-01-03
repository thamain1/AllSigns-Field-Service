import { useState, useEffect } from 'react';
import { X, FileText, Calendar, DollarSign } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../contexts/AuthContext';

interface Vendor {
  id: string;
  name: string;
  vendor_code: string;
}

interface NewVendorContractModalProps {
  vendorId?: string;
  onClose: () => void;
}

export function NewVendorContractModal({ vendorId, onClose }: NewVendorContractModalProps) {
  const { profile } = useAuth();
  const [vendors, setVendors] = useState<Vendor[]>([]);
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState({
    vendor_id: vendorId || '',
    contract_type: 'pricing',
    status: 'draft',
    start_date: new Date().toISOString().split('T')[0],
    end_date: '',
    auto_renew: false,
    renewal_term_months: '',
    payment_terms: '',
    freight_terms: '',
    minimum_order_value: '',
    free_freight_threshold: '',
    standard_lead_time_days: '',
    rush_lead_time_days: '',
    return_policy: '',
    warranty_terms: '',
    is_preferred_vendor: false,
    contract_value: '',
    notes: '',
  });

  useEffect(() => {
    if (!vendorId) {
      loadVendors();
    }
  }, [vendorId]);

  const loadVendors = async () => {
    try {
      const { data, error } = await supabase
        .from('vendors')
        .select('id, name, vendor_code')
        .eq('is_active', true)
        .order('name');

      if (error) throw error;
      setVendors(data || []);
    } catch (error) {
      console.error('Error loading vendors:', error);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      const contractData = {
        vendor_id: formData.vendor_id,
        contract_type: formData.contract_type,
        status: formData.status,
        start_date: formData.start_date,
        end_date: formData.end_date || null,
        auto_renew: formData.auto_renew,
        renewal_term_months: formData.renewal_term_months ? parseInt(formData.renewal_term_months) : null,
        payment_terms: formData.payment_terms || null,
        freight_terms: formData.freight_terms || null,
        minimum_order_value: formData.minimum_order_value ? parseFloat(formData.minimum_order_value) : null,
        free_freight_threshold: formData.free_freight_threshold ? parseFloat(formData.free_freight_threshold) : null,
        standard_lead_time_days: formData.standard_lead_time_days ? parseInt(formData.standard_lead_time_days) : null,
        rush_lead_time_days: formData.rush_lead_time_days ? parseInt(formData.rush_lead_time_days) : null,
        return_policy: formData.return_policy || null,
        warranty_terms: formData.warranty_terms || null,
        is_preferred_vendor: formData.is_preferred_vendor,
        contract_value: formData.contract_value ? parseFloat(formData.contract_value) : null,
        notes: formData.notes || null,
        created_by: profile?.id,
      };

      const { error } = await supabase
        .from('vendor_contracts')
        .insert([contractData]);

      if (error) throw error;

      onClose();
    } catch (error) {
      console.error('Error creating vendor contract:', error);
      alert('Failed to create contract. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white dark:bg-gray-800 rounded-lg shadow-xl w-full max-w-4xl max-h-[90vh] overflow-hidden flex flex-col">
        <div className="flex items-center justify-between p-6 border-b border-gray-200 dark:border-gray-700">
          <h2 className="text-2xl font-semibold text-gray-900 dark:text-white flex items-center">
            <FileText className="w-6 h-6 mr-2" />
            New Vendor Contract
          </h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="flex-1 overflow-y-auto p-6">
          <div className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {!vendorId && (
                <div className="md:col-span-2">
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Vendor *
                  </label>
                  <select
                    required
                    value={formData.vendor_id}
                    onChange={(e) => setFormData({ ...formData, vendor_id: e.target.value })}
                    className="input w-full"
                  >
                    <option value="">Select a vendor...</option>
                    {vendors.map((vendor) => (
                      <option key={vendor.id} value={vendor.id}>
                        {vendor.name} ({vendor.vendor_code})
                      </option>
                    ))}
                  </select>
                </div>
              )}

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Contract Type *
                </label>
                <select
                  required
                  value={formData.contract_type}
                  onChange={(e) => setFormData({ ...formData, contract_type: e.target.value })}
                  className="input w-full"
                >
                  <option value="pricing">Pricing Agreement</option>
                  <option value="service">Service Agreement</option>
                  <option value="warranty">Warranty Agreement</option>
                  <option value="rebate">Rebate Program</option>
                  <option value="distribution">Distribution Agreement</option>
                  <option value="msa">Master Service Agreement</option>
                  <option value="other">Other</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Status *
                </label>
                <select
                  required
                  value={formData.status}
                  onChange={(e) => setFormData({ ...formData, status: e.target.value })}
                  className="input w-full"
                >
                  <option value="draft">Draft</option>
                  <option value="active">Active</option>
                  <option value="suspended">Suspended</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Start Date *
                </label>
                <input
                  type="date"
                  required
                  value={formData.start_date}
                  onChange={(e) => setFormData({ ...formData, start_date: e.target.value })}
                  className="input w-full"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  End Date
                </label>
                <input
                  type="date"
                  value={formData.end_date}
                  onChange={(e) => setFormData({ ...formData, end_date: e.target.value })}
                  className="input w-full"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Contract Value
                </label>
                <div className="relative">
                  <DollarSign className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    value={formData.contract_value}
                    onChange={(e) => setFormData({ ...formData, contract_value: e.target.value })}
                    className="input w-full pl-10"
                    placeholder="0.00"
                  />
                </div>
              </div>

              <div>
                <label className="flex items-center space-x-2 text-sm font-medium text-gray-700 dark:text-gray-300">
                  <input
                    type="checkbox"
                    checked={formData.auto_renew}
                    onChange={(e) => setFormData({ ...formData, auto_renew: e.target.checked })}
                    className="rounded border-gray-300"
                  />
                  <span>Auto-Renew</span>
                </label>
                {formData.auto_renew && (
                  <input
                    type="number"
                    min="1"
                    value={formData.renewal_term_months}
                    onChange={(e) => setFormData({ ...formData, renewal_term_months: e.target.value })}
                    placeholder="Renewal term (months)"
                    className="input w-full mt-2"
                  />
                )}
              </div>
            </div>

            <div className="border-t border-gray-200 dark:border-gray-700 pt-6">
              <h3 className="text-lg font-medium text-gray-900 dark:text-white mb-4">
                Commercial Terms
              </h3>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Payment Terms
                  </label>
                  <input
                    type="text"
                    value={formData.payment_terms}
                    onChange={(e) => setFormData({ ...formData, payment_terms: e.target.value })}
                    placeholder="e.g., Net 30, 2% 10 Net 30"
                    className="input w-full"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Freight Terms
                  </label>
                  <input
                    type="text"
                    value={formData.freight_terms}
                    onChange={(e) => setFormData({ ...formData, freight_terms: e.target.value })}
                    placeholder="e.g., FOB Origin, Prepaid & Add"
                    className="input w-full"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Minimum Order Value
                  </label>
                  <div className="relative">
                    <DollarSign className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
                    <input
                      type="number"
                      step="0.01"
                      min="0"
                      value={formData.minimum_order_value}
                      onChange={(e) => setFormData({ ...formData, minimum_order_value: e.target.value })}
                      className="input w-full pl-10"
                      placeholder="0.00"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Free Freight Threshold
                  </label>
                  <div className="relative">
                    <DollarSign className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
                    <input
                      type="number"
                      step="0.01"
                      min="0"
                      value={formData.free_freight_threshold}
                      onChange={(e) => setFormData({ ...formData, free_freight_threshold: e.target.value })}
                      className="input w-full pl-10"
                      placeholder="0.00"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Standard Lead Time (days)
                  </label>
                  <input
                    type="number"
                    min="0"
                    value={formData.standard_lead_time_days}
                    onChange={(e) => setFormData({ ...formData, standard_lead_time_days: e.target.value })}
                    className="input w-full"
                    placeholder="e.g., 7"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Rush Lead Time (days)
                  </label>
                  <input
                    type="number"
                    min="0"
                    value={formData.rush_lead_time_days}
                    onChange={(e) => setFormData({ ...formData, rush_lead_time_days: e.target.value })}
                    className="input w-full"
                    placeholder="e.g., 3"
                  />
                </div>

                <div className="md:col-span-2">
                  <label className="flex items-center space-x-2 text-sm font-medium text-gray-700 dark:text-gray-300">
                    <input
                      type="checkbox"
                      checked={formData.is_preferred_vendor}
                      onChange={(e) => setFormData({ ...formData, is_preferred_vendor: e.target.checked })}
                      className="rounded border-gray-300"
                    />
                    <span>Mark as Preferred Vendor</span>
                  </label>
                </div>
              </div>
            </div>

            <div className="border-t border-gray-200 dark:border-gray-700 pt-6">
              <h3 className="text-lg font-medium text-gray-900 dark:text-white mb-4">
                Policies
              </h3>

              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Return Policy
                  </label>
                  <textarea
                    value={formData.return_policy}
                    onChange={(e) => setFormData({ ...formData, return_policy: e.target.value })}
                    rows={3}
                    className="input w-full"
                    placeholder="Describe the return policy..."
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Warranty Terms
                  </label>
                  <textarea
                    value={formData.warranty_terms}
                    onChange={(e) => setFormData({ ...formData, warranty_terms: e.target.value })}
                    rows={3}
                    className="input w-full"
                    placeholder="Describe warranty terms..."
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Notes
                  </label>
                  <textarea
                    value={formData.notes}
                    onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
                    rows={3}
                    className="input w-full"
                    placeholder="Additional notes..."
                  />
                </div>
              </div>
            </div>
          </div>
        </form>

        <div className="flex justify-end gap-3 p-6 border-t border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900">
          <button
            type="button"
            onClick={onClose}
            className="btn btn-secondary"
            disabled={loading}
          >
            Cancel
          </button>
          <button
            onClick={handleSubmit}
            className="btn btn-primary"
            disabled={loading}
          >
            {loading ? 'Creating...' : 'Create Contract'}
          </button>
        </div>
      </div>
    </div>
  );
}

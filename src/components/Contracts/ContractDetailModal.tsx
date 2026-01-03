import { useState, useEffect } from 'react';
import { X, FileText, Calendar, DollarSign, TrendingUp, Users, Settings } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import type { Database } from '../../lib/database.types';

type ServiceContract = Database['public']['Tables']['service_contracts']['Row'] & {
  customers?: { name: string; email: string };
  customer_locations?: { location_name: string; address: string };
  contract_plans?: { name: string; description: string };
};

interface ContractDetailModalProps {
  contract: ServiceContract;
  onClose: () => void;
}

export function ContractDetailModal({ contract: initialContract, onClose }: ContractDetailModalProps) {
  const [contract, setContract] = useState(initialContract);
  const [editing, setEditing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [formData, setFormData] = useState({
    name: contract.name,
    status: contract.status,
    start_date: contract.start_date,
    end_date: contract.end_date || '',
    base_fee: contract.base_fee?.toString() || '0',
    auto_renew: contract.auto_renew,
    notes: contract.notes || '',
  });

  const handleUpdate = async () => {
    try {
      setSaving(true);

      const { error } = await supabase
        .from('service_contracts')
        .update({
          name: formData.name,
          status: formData.status as any,
          start_date: formData.start_date,
          end_date: formData.end_date || null,
          base_fee: parseFloat(formData.base_fee),
          auto_renew: formData.auto_renew,
          notes: formData.notes,
        })
        .eq('id', contract.id);

      if (error) throw error;

      const { data: updated, error: fetchError } = await supabase
        .from('service_contracts')
        .select(`
          *,
          customers(name, email),
          customer_locations(location_name, address),
          contract_plans(name, description)
        `)
        .eq('id', contract.id)
        .single();

      if (fetchError) throw fetchError;

      setContract(updated);
      setEditing(false);
      alert('Contract updated successfully!');
    } catch (error: any) {
      console.error('Error updating contract:', error);
      alert(`Failed to update contract: ${error.message}`);
    } finally {
      setSaving(false);
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'active':
        return 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400';
      case 'draft':
        return 'bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-400';
      case 'expired':
        return 'bg-orange-100 text-orange-800 dark:bg-orange-900/30 dark:text-orange-400';
      case 'cancelled':
      case 'suspended':
        return 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400';
      default:
        return 'bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-400';
    }
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
    }).format(amount);
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4 overflow-y-auto">
      <div className="bg-white dark:bg-gray-800 rounded-xl shadow-2xl max-w-4xl w-full my-8">
        <div className="flex items-center justify-between p-6 border-b border-gray-200 dark:border-gray-700">
          <div className="flex items-center">
            <FileText className="w-6 h-6 text-blue-600 mr-3" />
            <div>
              <h2 className="text-2xl font-bold text-gray-900 dark:text-white">{contract.name}</h2>
              <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
                {contract.customers?.name}
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        <div className="p-6 space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="card p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-xs text-gray-600 dark:text-gray-400">Status</p>
                  <span className={`badge ${getStatusColor(contract.status)} mt-1`}>
                    {contract.status.charAt(0).toUpperCase() + contract.status.slice(1)}
                  </span>
                </div>
                <Settings className="w-8 h-8 text-gray-400" />
              </div>
            </div>

            <div className="card p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-xs text-gray-600 dark:text-gray-400">Base Fee</p>
                  <p className="text-lg font-bold text-gray-900 dark:text-white mt-1">
                    {formatCurrency(contract.base_fee || 0)}
                  </p>
                </div>
                <DollarSign className="w-8 h-8 text-gray-400" />
              </div>
            </div>

            <div className="card p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-xs text-gray-600 dark:text-gray-400">Visits Used</p>
                  <p className="text-lg font-bold text-gray-900 dark:text-white mt-1">
                    {contract.visits_used_current_term} / {contract.included_visits_per_year}
                  </p>
                </div>
                <TrendingUp className="w-8 h-8 text-gray-400" />
              </div>
            </div>
          </div>

          {editing ? (
            <div className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Contract Name
                  </label>
                  <input
                    type="text"
                    value={formData.name}
                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    className="input"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Status
                  </label>
                  <select
                    value={formData.status}
                    onChange={(e) => setFormData({ ...formData, status: e.target.value as any })}
                    className="input"
                  >
                    <option value="draft">Draft</option>
                    <option value="active">Active</option>
                    <option value="suspended">Suspended</option>
                    <option value="expired">Expired</option>
                    <option value="cancelled">Cancelled</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Start Date
                  </label>
                  <input
                    type="date"
                    value={formData.start_date}
                    onChange={(e) => setFormData({ ...formData, start_date: e.target.value })}
                    className="input"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    End Date
                  </label>
                  <input
                    type="date"
                    value={formData.end_date}
                    onChange={(e) => setFormData({ ...formData, end_date: e.target.value })}
                    className="input"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Base Fee
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    value={formData.base_fee}
                    onChange={(e) => setFormData({ ...formData, base_fee: e.target.value })}
                    className="input"
                  />
                </div>

                <div className="flex items-center">
                  <label className="flex items-center">
                    <input
                      type="checkbox"
                      checked={formData.auto_renew}
                      onChange={(e) => setFormData({ ...formData, auto_renew: e.target.checked })}
                      className="w-4 h-4 text-blue-600 rounded"
                    />
                    <span className="ml-2 text-sm text-gray-700 dark:text-gray-300">
                      Auto-renew
                    </span>
                  </label>
                </div>

                <div className="md:col-span-2">
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Notes
                  </label>
                  <textarea
                    value={formData.notes}
                    onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
                    rows={3}
                    className="input"
                  />
                </div>
              </div>

              <div className="flex items-center justify-end space-x-3 pt-4 border-t border-gray-200 dark:border-gray-700">
                <button
                  onClick={() => setEditing(false)}
                  className="btn-outline"
                  disabled={saving}
                >
                  Cancel
                </button>
                <button onClick={handleUpdate} className="btn-primary" disabled={saving}>
                  {saving ? (
                    <>
                      <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
                      Saving...
                    </>
                  ) : (
                    'Save Changes'
                  )}
                </button>
              </div>
            </div>
          ) : (
            <div className="space-y-6">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <h3 className="text-sm font-medium text-gray-500 dark:text-gray-400 mb-2">
                    Contract Details
                  </h3>
                  <div className="space-y-3">
                    <div>
                      <p className="text-xs text-gray-500">Plan</p>
                      <p className="text-sm font-medium text-gray-900 dark:text-white">
                        {contract.contract_plans?.name}
                      </p>
                    </div>
                    <div>
                      <p className="text-xs text-gray-500">Billing Frequency</p>
                      <p className="text-sm font-medium text-gray-900 dark:text-white">
                        {contract.billing_frequency.replace('_', ' ').toUpperCase()}
                      </p>
                    </div>
                    {contract.customer_locations && (
                      <div>
                        <p className="text-xs text-gray-500">Location</p>
                        <p className="text-sm font-medium text-gray-900 dark:text-white">
                          {contract.customer_locations.location_name}
                        </p>
                      </div>
                    )}
                  </div>
                </div>

                <div>
                  <h3 className="text-sm font-medium text-gray-500 dark:text-gray-400 mb-2">
                    Coverage Details
                  </h3>
                  <div className="space-y-3">
                    <div>
                      <p className="text-xs text-gray-500">Labor Discount</p>
                      <p className="text-sm font-medium text-gray-900 dark:text-white">
                        {contract.labor_discount_percent}%
                      </p>
                    </div>
                    <div>
                      <p className="text-xs text-gray-500">Parts Discount</p>
                      <p className="text-sm font-medium text-gray-900 dark:text-white">
                        {contract.parts_discount_percent}%
                      </p>
                    </div>
                    <div>
                      <p className="text-xs text-gray-500">Priority Level</p>
                      <p className="text-sm font-medium text-gray-900 dark:text-white">
                        {contract.priority_level.toUpperCase()}
                      </p>
                    </div>
                    <div>
                      <p className="text-xs text-gray-500">Response SLA</p>
                      <p className="text-sm font-medium text-gray-900 dark:text-white">
                        {contract.response_time_sla_hours} hours
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              {contract.notes && (
                <div>
                  <h3 className="text-sm font-medium text-gray-500 dark:text-gray-400 mb-2">
                    Notes
                  </h3>
                  <p className="text-sm text-gray-700 dark:text-gray-300">{contract.notes}</p>
                </div>
              )}

              <div className="flex items-center justify-end space-x-3 pt-4 border-t border-gray-200 dark:border-gray-700">
                <button onClick={() => setEditing(true)} className="btn-primary">
                  Edit Contract
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

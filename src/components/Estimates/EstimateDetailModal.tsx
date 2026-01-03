import { useState, useEffect } from 'react';
import { X, FileText, User, Calendar, Mail, Phone, MapPin, Edit, Save, Plus, Trash2, Send, CheckCircle, XCircle, Repeat } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../contexts/AuthContext';

type EstimateDetail = {
  id: string;
  estimate_number: string;
  customer_id: string;
  job_title: string;
  job_description: string;
  site_location: string;
  status: string;
  subtotal: number;
  tax_rate: number;
  tax_amount: number;
  total_amount: number;
  estimate_date: string;
  expiration_date: string;
  notes: string;
  terms_conditions: string;
  created_at: string;
  converted_to_ticket_id?: string | null;
  converted_to_project_id?: string | null;
  customers?: {
    name: string;
    email: string;
    phone: string;
    address: string;
  };
  profiles?: {
    full_name: string;
  };
};

type LineItem = {
  id: string;
  line_order: number;
  item_type: string;
  description: string;
  quantity: number;
  unit_price: number;
  line_total: number;
  part_id?: string;
  equipment_id?: string;
  labor_hours?: number;
  labor_rate?: number;
};

interface EstimateDetailModalProps {
  estimateId: string | null;
  isOpen: boolean;
  onClose: () => void;
}

export function EstimateDetailModal({ estimateId, isOpen, onClose }: EstimateDetailModalProps) {
  const { profile } = useAuth();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [converting, setConverting] = useState(false);
  const [editing, setEditing] = useState(false);
  const [estimate, setEstimate] = useState<EstimateDetail | null>(null);
  const [lineItems, setLineItems] = useState<LineItem[]>([]);
  const [parts, setParts] = useState<any[]>([]);
  const [equipment, setEquipment] = useState<any[]>([]);
  const [laborRates, setLaborRates] = useState<Array<{ key: string; name: string; rate: number }>>([]);

  useEffect(() => {
    if (isOpen && estimateId) {
      loadEstimateDetails();
      loadData();
    }
  }, [isOpen, estimateId]);

  const loadData = async () => {
    try {
      const [laborRatesRes, partsRes, equipmentRes] = await Promise.all([
        supabase
          .from('labor_rate_profile')
          .select('*')
          .eq('is_active', true)
          .single(),
        supabase.from('parts').select('*').order('name'),
        supabase.from('equipment').select('*').order('manufacturer, model_number'),
      ]);

      if (laborRatesRes.data) {
        const profile = laborRatesRes.data;
        const rates = [
          { key: 'standard', name: 'Standard Rate', rate: Number(profile.standard_rate) },
          { key: 'after_hours', name: 'After-Hours Rate', rate: Number(profile.after_hours_rate) },
          { key: 'emergency', name: 'Emergency Rate', rate: Number(profile.emergency_rate) }
        ];
        setLaborRates(rates);
      }

      if (partsRes.data) setParts(partsRes.data);
      if (equipmentRes.data) setEquipment(equipmentRes.data);
    } catch (error) {
      console.error('Error loading data:', error);
    }
  };

  const loadEstimateDetails = async () => {
    if (!estimateId) return;

    setLoading(true);
    try {
      const [estimateRes, lineItemsRes] = await Promise.all([
        supabase
          .from('estimates')
          .select(`
            *,
            customers(name, email, phone, address),
            profiles:assigned_to(full_name)
          `)
          .eq('id', estimateId)
          .single(),
        supabase
          .from('estimate_line_items')
          .select('*')
          .eq('estimate_id', estimateId)
          .order('line_order'),
      ]);

      if (estimateRes.error) throw estimateRes.error;
      if (lineItemsRes.error) throw lineItemsRes.error;

      setEstimate(estimateRes.data);
      setLineItems(lineItemsRes.data || []);
    } catch (error) {
      console.error('Error loading estimate details:', error);
    } finally {
      setLoading(false);
    }
  };

  const calculateTotals = () => {
    const subtotal = lineItems.reduce((sum, item) =>
      item.item_type !== 'discount' ? sum + Number(item.line_total) : sum, 0
    );
    const discount = lineItems.reduce((sum, item) =>
      item.item_type === 'discount' ? sum + Math.abs(Number(item.line_total)) : sum, 0
    );
    const taxAmount = (subtotal - discount) * ((estimate?.tax_rate || 0) / 100);
    const total = subtotal - discount + taxAmount;

    return { subtotal, discount, taxAmount, total };
  };

  const updateLineItem = (id: string, field: keyof LineItem, value: any) => {
    setLineItems(lineItems.map(item => {
      if (item.id === id) {
        const updated = { ...item, [field]: value };
        if (field === 'quantity' || field === 'unit_price') {
          updated.line_total = Number(updated.quantity) * Number(updated.unit_price);
        }
        return updated;
      }
      return item;
    }));
  };

  const handleLaborRateSelect = (itemId: string, rateKey: string) => {
    const rate = laborRates.find(r => r.key === rateKey);
    if (rate) {
      setLineItems(lineItems.map(item => {
        if (item.id === itemId) {
          return {
            ...item,
            description: rate.name,
            unit_price: rate.rate,
            labor_rate: rate.rate,
            line_total: Number(item.quantity) * Number(rate.rate)
          };
        }
        return item;
      }));
    }
  };

  const handlePartSelect = (itemId: string, partId: string) => {
    const part = parts.find(p => p.id === partId);
    if (part) {
      setLineItems(lineItems.map(item => {
        if (item.id === itemId) {
          const unitPrice = Number(part.cost || 0);
          return {
            ...item,
            part_id: partId,
            description: part.name,
            unit_price: unitPrice,
            line_total: Number(item.quantity) * unitPrice
          };
        }
        return item;
      }));
    }
  };

  const handleEquipmentSelect = (itemId: string, equipmentId: string) => {
    const equip = equipment.find(e => e.id === equipmentId);
    if (equip) {
      setLineItems(lineItems.map(item => {
        if (item.id === itemId) {
          return {
            ...item,
            equipment_id: equipmentId,
            description: `${equip.manufacturer} ${equip.model_number}`,
            unit_price: 0,
            line_total: 0
          };
        }
        return item;
      }));
    }
  };

  const addLineItem = () => {
    setLineItems([...lineItems, {
      id: crypto.randomUUID(),
      line_order: lineItems.length,
      item_type: 'labor',
      description: '',
      quantity: 1,
      unit_price: 0,
      line_total: 0,
    }]);
  };

  const removeLineItem = (id: string) => {
    if (lineItems.length > 1) {
      setLineItems(lineItems.filter(item => item.id !== id));
    }
  };

  const handleSave = async () => {
    if (!estimate) return;

    setSaving(true);
    try {
      const totals = calculateTotals();

      const { error: estimateError } = await supabase
        .from('estimates')
        .update({
          job_title: estimate.job_title,
          job_description: estimate.job_description,
          site_location: estimate.site_location,
          tax_rate: estimate.tax_rate,
          subtotal: totals.subtotal,
          tax_amount: totals.taxAmount,
          total_amount: totals.total,
          notes: estimate.notes,
          terms_conditions: estimate.terms_conditions,
        })
        .eq('id', estimate.id);

      if (estimateError) throw estimateError;

      const { error: deleteError } = await supabase
        .from('estimate_line_items')
        .delete()
        .eq('estimate_id', estimate.id);

      if (deleteError) throw deleteError;

      const lineItemsToInsert = lineItems
        .filter(item => item.description && item.description.trim() !== '')
        .map((item, index) => ({
          estimate_id: estimate.id,
          line_order: index,
          item_type: item.item_type,
          description: item.description,
          quantity: item.quantity,
          unit_price: item.unit_price,
          line_total: item.line_total,
          part_id: item.part_id || null,
          equipment_id: item.equipment_id || null,
          labor_hours: item.item_type === 'labor' ? item.quantity : null,
          labor_rate: item.item_type === 'labor' ? item.unit_price : null,
        }));

      console.log('All line items before filter:', lineItems);
      console.log('Line items to insert after filter:', lineItemsToInsert);

      if (lineItemsToInsert.length > 0) {
        const { data: insertedItems, error: lineItemsError } = await supabase
          .from('estimate_line_items')
          .insert(lineItemsToInsert)
          .select();

        if (lineItemsError) {
          console.error('Error inserting line items:', lineItemsError);
          throw lineItemsError;
        }

        console.log('Inserted line items:', insertedItems);
      } else {
        console.warn('No line items to insert - all items filtered out');
      }

      setEditing(false);
      await loadEstimateDetails();
    } catch (error) {
      console.error('Error saving estimate:', error);
      alert('Failed to save estimate. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  const handleCancel = () => {
    setEditing(false);
    loadEstimateDetails();
  };

  const handleStatusChange = async (newStatus: 'sent' | 'accepted' | 'rejected') => {
    if (!estimate) return;

    try {
      const updateData: any = { status: newStatus };

      if (newStatus === 'sent') {
        updateData.sent_date = new Date().toISOString();
      } else if (newStatus === 'accepted') {
        updateData.accepted_date = new Date().toISOString();
      } else if (newStatus === 'rejected') {
        updateData.rejected_date = new Date().toISOString();
      }

      const { error } = await supabase
        .from('estimates')
        .update(updateData)
        .eq('id', estimate.id);

      if (error) throw error;

      await loadEstimateDetails();
      alert(`Estimate ${newStatus} successfully`);
    } catch (error) {
      console.error(`Error marking estimate as ${newStatus}:`, error);
      alert(`Failed to mark estimate as ${newStatus}. Please try again.`);
    }
  };

  const handleConvertToTicket = async () => {
    if (!estimate || !profile) return;

    if (!confirm('Convert this estimate to a service ticket?')) return;

    setConverting(true);
    try {
      const { data: ticketData, error: ticketError } = await supabase
        .from('tickets')
        .insert({
          customer_id: estimate.customer_id,
          title: estimate.job_title,
          description: estimate.job_description || 'Converted from estimate',
          ticket_type: 'SVC',
          status: 'open',
          priority: 'normal',
          created_by: profile.id,
          assigned_to: profile.id,
        })
        .select()
        .single();

      if (ticketError) throw ticketError;

      const { error: updateError } = await supabase
        .from('estimates')
        .update({
          status: 'converted',
          converted_to_ticket_id: ticketData.id,
          conversion_date: new Date().toISOString(),
        })
        .eq('id', estimate.id);

      if (updateError) throw updateError;

      alert(`Successfully converted to ticket #${ticketData.ticket_number || ticketData.id}`);
      await loadEstimateDetails();
    } catch (error) {
      console.error('Error converting to ticket:', error);
      alert('Failed to convert to ticket. Please try again.');
    } finally {
      setConverting(false);
    }
  };

  const handleConvertToProject = async () => {
    if (!estimate || !profile) return;

    if (!confirm('Convert this estimate to a project?')) return;

    setConverting(true);
    try {
      const { data: projectData, error: projectError } = await supabase
        .from('projects')
        .insert({
          customer_id: estimate.customer_id,
          name: estimate.job_title,
          description: estimate.job_description || '',
          status: 'planning',
          budget_amount: estimate.total_amount,
          project_manager_id: profile.id,
        })
        .select()
        .single();

      if (projectError) throw projectError;

      const { error: updateError } = await supabase
        .from('estimates')
        .update({
          status: 'converted',
          converted_to_project_id: projectData.id,
          conversion_date: new Date().toISOString(),
        })
        .eq('id', estimate.id);

      if (updateError) throw updateError;

      alert(`Successfully converted to project "${projectData.name}"`);
      await loadEstimateDetails();
    } catch (error) {
      console.error('Error converting to project:', error);
      alert('Failed to convert to project. Please try again.');
    } finally {
      setConverting(false);
    }
  };

  if (!isOpen) return null;

  const totals = calculateTotals();

  return (
    <div className="fixed inset-0 bg-black/50 flex items-start justify-center z-50 overflow-y-auto p-4">
      <div className="bg-white dark:bg-gray-800 rounded-xl shadow-xl w-full max-w-5xl my-8">
        <div className="flex items-center justify-between p-6 border-b border-gray-200 dark:border-gray-700">
          <div className="flex items-center space-x-3">
            <FileText className="w-6 h-6 text-blue-600" />
            <div>
              <h2 className="text-xl font-bold text-gray-900 dark:text-white">
                {estimate?.estimate_number || 'Loading...'}
              </h2>
              {editing ? (
                <input
                  type="text"
                  value={estimate?.job_title || ''}
                  onChange={(e) => setEstimate(estimate ? { ...estimate, job_title: e.target.value } : null)}
                  className="input text-sm mt-1"
                  placeholder="Job title"
                />
              ) : (
                <p className="text-sm text-gray-500 dark:text-gray-400">
                  {estimate?.job_title}
                </p>
              )}
            </div>
          </div>
          <div className="flex items-center space-x-2">
            {editing ? (
              <>
                <button
                  onClick={handleCancel}
                  disabled={saving}
                  className="btn btn-outline"
                >
                  Cancel
                </button>
                <button
                  onClick={handleSave}
                  disabled={saving}
                  className="btn btn-primary flex items-center space-x-2"
                >
                  <Save className="w-4 h-4" />
                  <span>{saving ? 'Saving...' : 'Save'}</span>
                </button>
              </>
            ) : (
              <button
                onClick={() => setEditing(true)}
                className="btn btn-outline flex items-center space-x-2"
              >
                <Edit className="w-4 h-4" />
                <span>Edit</span>
              </button>
            )}
            <button
              onClick={onClose}
              className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
            >
              <X className="w-6 h-6" />
            </button>
          </div>
        </div>

        {loading ? (
          <div className="flex items-center justify-center h-64">
            <div className="text-gray-500">Loading estimate details...</div>
          </div>
        ) : estimate ? (
          <div className="p-6 space-y-6">
            <div className="flex items-center justify-between">
              <span className="badge badge-gray">
                {estimate.status.toUpperCase()}
              </span>
              <div className="text-sm text-gray-500 dark:text-gray-400">
                Created {new Date(estimate.created_at).toLocaleDateString()}
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="card p-4">
                <h3 className="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3 flex items-center">
                  <User className="w-4 h-4 mr-2" />
                  Customer Information
                </h3>
                <div className="space-y-2 text-sm">
                  <div className="font-medium text-gray-900 dark:text-white">
                    {estimate.customers?.name}
                  </div>
                  {estimate.customers?.email && (
                    <div className="flex items-center text-gray-600 dark:text-gray-400">
                      <Mail className="w-4 h-4 mr-2" />
                      {estimate.customers.email}
                    </div>
                  )}
                  {estimate.customers?.phone && (
                    <div className="flex items-center text-gray-600 dark:text-gray-400">
                      <Phone className="w-4 h-4 mr-2" />
                      {estimate.customers.phone}
                    </div>
                  )}
                  {estimate.customers?.address && (
                    <div className="flex items-center text-gray-600 dark:text-gray-400">
                      <MapPin className="w-4 h-4 mr-2" />
                      {estimate.customers.address}
                    </div>
                  )}
                </div>
              </div>

              <div className="card p-4">
                <h3 className="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3 flex items-center">
                  <Calendar className="w-4 h-4 mr-2" />
                  Estimate Details
                </h3>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span className="text-gray-600 dark:text-gray-400">Estimate Date:</span>
                    <span className="font-medium text-gray-900 dark:text-white">
                      {new Date(estimate.estimate_date).toLocaleDateString()}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600 dark:text-gray-400">Expiration Date:</span>
                    <span className="font-medium text-gray-900 dark:text-white">
                      {new Date(estimate.expiration_date).toLocaleDateString()}
                    </span>
                  </div>
                  {estimate.site_location && (
                    <div className="flex justify-between">
                      <span className="text-gray-600 dark:text-gray-400">Site Location:</span>
                      <span className="font-medium text-gray-900 dark:text-white">
                        {estimate.site_location}
                      </span>
                    </div>
                  )}
                </div>
              </div>
            </div>

            {(editing || estimate.job_description) && (
              <div className="card p-4">
                <h3 className="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-2">
                  Job Description
                </h3>
                {editing ? (
                  <textarea
                    value={estimate.job_description || ''}
                    onChange={(e) => setEstimate({ ...estimate, job_description: e.target.value })}
                    className="input min-h-[100px]"
                    placeholder="Describe the job..."
                  />
                ) : (
                  <p className="text-sm text-gray-600 dark:text-gray-400 whitespace-pre-wrap">
                    {estimate.job_description}
                  </p>
                )}
              </div>
            )}

            <div className="card p-4">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-sm font-semibold text-gray-700 dark:text-gray-300">
                  Line Items
                </h3>
                {editing && (
                  <button
                    onClick={addLineItem}
                    className="btn btn-outline btn-sm flex items-center space-x-1"
                  >
                    <Plus className="w-4 h-4" />
                    <span>Add Line Item</span>
                  </button>
                )}
              </div>
              <div className="space-y-3">
                {lineItems.map((item) => (
                  <div key={item.id} className="border border-gray-200 dark:border-gray-700 rounded-lg p-3">
                    <div className="grid grid-cols-12 gap-2">
                      <div className="col-span-2">
                        <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">
                          Type
                        </label>
                        {editing ? (
                          <select
                            value={item.item_type}
                            onChange={(e) => updateLineItem(item.id, 'item_type', e.target.value)}
                            className="input text-sm"
                          >
                            <option value="labor">Labor</option>
                            <option value="parts">Parts</option>
                            <option value="equipment">Equipment</option>
                            <option value="other">Other</option>
                          </select>
                        ) : (
                          <div className="text-sm font-medium text-gray-900 dark:text-white capitalize">{item.item_type}</div>
                        )}
                      </div>

                      <div className="col-span-4">
                        <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">
                          {item.item_type === 'labor' ? 'Labor Rate' : item.item_type === 'parts' ? 'Part' : item.item_type === 'equipment' ? 'Equipment' : 'Description'}
                        </label>
                        {editing ? (
                          item.item_type === 'labor' ? (
                            <select
                              onChange={(e) => handleLaborRateSelect(item.id, e.target.value)}
                              className="input text-sm"
                              defaultValue=""
                            >
                              <option value="">Select labor rate...</option>
                              {laborRates.map((rate) => (
                                <option key={rate.key} value={rate.key}>
                                  {rate.name} (${rate.rate}/hr)
                                </option>
                              ))}
                            </select>
                          ) : item.item_type === 'parts' ? (
                            <select
                              onChange={(e) => handlePartSelect(item.id, e.target.value)}
                              className="input text-sm"
                              defaultValue=""
                            >
                              <option value="">Select part...</option>
                              {parts.map((part) => (
                                <option key={part.id} value={part.id}>
                                  {part.name} - ${part.cost}
                                </option>
                              ))}
                            </select>
                          ) : item.item_type === 'equipment' ? (
                            <select
                              onChange={(e) => handleEquipmentSelect(item.id, e.target.value)}
                              className="input text-sm"
                              defaultValue=""
                            >
                              <option value="">Select equipment...</option>
                              {equipment.map((equip) => (
                                <option key={equip.id} value={equip.id}>
                                  {equip.manufacturer} {equip.model_number}
                                </option>
                              ))}
                            </select>
                          ) : (
                            <input
                              type="text"
                              value={item.description}
                              onChange={(e) => updateLineItem(item.id, 'description', e.target.value)}
                              className="input text-sm"
                              placeholder="Description"
                            />
                          )
                        ) : (
                          <div className="text-sm text-gray-900 dark:text-white">{item.description}</div>
                        )}
                      </div>

                      <div className="col-span-2">
                        <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">
                          {item.item_type === 'labor' ? 'Hours' : 'Qty'}
                        </label>
                        {editing ? (
                          <input
                            type="number"
                            step={item.item_type === 'labor' ? '0.25' : '0.01'}
                            min={item.item_type === 'labor' ? '1' : '0'}
                            value={item.quantity}
                            onChange={(e) => updateLineItem(item.id, 'quantity', parseFloat(e.target.value) || (item.item_type === 'labor' ? 1 : 0))}
                            className="input text-sm"
                          />
                        ) : (
                          <div className="text-sm text-gray-900 dark:text-white">
                            {item.item_type === 'labor'
                              ? (() => {
                                  const hours = Math.floor(item.quantity);
                                  const minutes = Math.round((item.quantity - hours) * 60);
                                  return minutes === 0 ? `${hours}h` : `${hours}h ${minutes}m`;
                                })()
                              : item.quantity
                            }
                          </div>
                        )}
                      </div>

                      <div className="col-span-2">
                        <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">
                          Rate/Hr
                        </label>
                        {editing ? (
                          <input
                            type="number"
                            step="0.01"
                            min="0"
                            value={item.unit_price}
                            onChange={(e) => updateLineItem(item.id, 'unit_price', parseFloat(e.target.value) || 0)}
                            className="input text-sm"
                          />
                        ) : (
                          <div className="text-sm text-gray-900 dark:text-white">${Number(item.unit_price).toFixed(2)}</div>
                        )}
                      </div>

                      <div className="col-span-2">
                        <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">
                          Total
                        </label>
                        <div className="text-sm font-medium text-gray-900 dark:text-white">
                          ${Number(item.line_total).toFixed(2)}
                        </div>
                      </div>

                      {editing && lineItems.length > 1 && (
                        <div className="col-span-12 flex justify-end">
                          <button
                            onClick={() => removeLineItem(item.id)}
                            className="text-red-600 hover:text-red-800 text-sm flex items-center space-x-1"
                          >
                            <Trash2 className="w-4 h-4" />
                            <span>Remove</span>
                          </button>
                        </div>
                      )}
                    </div>
                  </div>
                ))}
              </div>

              <div className="mt-4 border-t border-gray-200 dark:border-gray-700 pt-4">
                <div className="flex justify-end">
                  <div className="w-64 space-y-2">
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-600 dark:text-gray-400">Subtotal:</span>
                      <span className="font-medium text-gray-900 dark:text-white">
                        ${totals.subtotal.toFixed(2)}
                      </span>
                    </div>
                    <div className="flex justify-between items-center text-sm">
                      <span className="text-gray-600 dark:text-gray-400">Tax:</span>
                      <div className="flex items-center space-x-2">
                        {editing ? (
                          <input
                            type="number"
                            step="0.01"
                            min="0"
                            max="100"
                            value={estimate.tax_rate}
                            onChange={(e) => setEstimate({ ...estimate, tax_rate: parseFloat(e.target.value) || 0 })}
                            className="input text-sm w-16 text-right"
                          />
                        ) : (
                          <span className="text-gray-600 dark:text-gray-400">
                            {estimate.tax_rate}%
                          </span>
                        )}
                        <span className="font-medium text-gray-900 dark:text-white">
                          ${totals.taxAmount.toFixed(2)}
                        </span>
                      </div>
                    </div>
                    <div className="flex justify-between text-lg font-bold border-t border-gray-200 dark:border-gray-700 pt-2">
                      <span className="text-gray-900 dark:text-white">Total:</span>
                      <span className="text-blue-600">
                        ${totals.total.toFixed(2)}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {(editing || estimate.notes) && (
              <div className="card p-4">
                <h3 className="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-2">
                  Notes
                </h3>
                {editing ? (
                  <textarea
                    value={estimate.notes || ''}
                    onChange={(e) => setEstimate({ ...estimate, notes: e.target.value })}
                    className="input min-h-[80px]"
                    placeholder="Add notes..."
                  />
                ) : (
                  <p className="text-sm text-gray-600 dark:text-gray-400 whitespace-pre-wrap">
                    {estimate.notes}
                  </p>
                )}
              </div>
            )}
          </div>
        ) : (
          <div className="p-6 text-center text-gray-500">
            Estimate not found
          </div>
        )}

        {!loading && estimate && (
          <div className="flex items-center justify-between p-6 border-t border-gray-200 dark:border-gray-700">
            <div className="flex items-center space-x-2">
              {estimate.status === 'draft' && (
                <button
                  onClick={() => handleStatusChange('sent')}
                  disabled={saving || converting}
                  className="btn btn-primary flex items-center space-x-2"
                >
                  <Send className="w-4 h-4" />
                  <span>Mark as Sent</span>
                </button>
              )}

              {(estimate.status === 'sent' || estimate.status === 'viewed') && (
                <>
                  <button
                    onClick={() => handleStatusChange('accepted')}
                    disabled={saving || converting}
                    className="btn btn-primary flex items-center space-x-2"
                  >
                    <CheckCircle className="w-4 h-4" />
                    <span>Accept</span>
                  </button>
                  <button
                    onClick={() => handleStatusChange('rejected')}
                    disabled={saving || converting}
                    className="btn btn-outline text-red-600 flex items-center space-x-2"
                  >
                    <XCircle className="w-4 h-4" />
                    <span>Reject</span>
                  </button>
                </>
              )}

              {estimate.status === 'accepted' && !estimate.converted_to_ticket_id && !estimate.converted_to_project_id && (
                <>
                  <button
                    onClick={handleConvertToTicket}
                    disabled={saving || converting}
                    className="btn btn-primary flex items-center space-x-2"
                  >
                    <Repeat className="w-4 h-4" />
                    <span>{converting ? 'Converting...' : 'Convert to Ticket'}</span>
                  </button>
                  <button
                    onClick={handleConvertToProject}
                    disabled={saving || converting}
                    className="btn btn-outline flex items-center space-x-2"
                  >
                    <Repeat className="w-4 h-4" />
                    <span>{converting ? 'Converting...' : 'Convert to Project'}</span>
                  </button>
                </>
              )}
            </div>

            <button onClick={onClose} className="btn btn-outline">
              Close
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

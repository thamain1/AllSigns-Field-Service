import { useState, useEffect } from 'react';
import { X, Clock, User, Calendar, MapPin, Wrench, AlertCircle } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import type { Database } from '../../lib/database.types';

type Ticket = Database['public']['Tables']['tickets']['Row'] & {
  customers?: { name: string; phone: string; address: string; city: string; state: string };
  profiles?: { full_name: string };
  equipment?: {
    model_number: string;
    manufacturer: string;
    equipment_type: string;
    serial_number: string;
  };
};

interface TicketDetailModalProps {
  isOpen: boolean;
  onClose: () => void;
  ticketId: string;
  onUpdate: () => void;
}

export function TicketDetailModal({ isOpen, onClose, ticketId, onUpdate }: TicketDetailModalProps) {
  const [ticket, setTicket] = useState<Ticket | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [hoursOnsite, setHoursOnsite] = useState<string>('');
  const [status, setStatus] = useState<string>('');

  useEffect(() => {
    if (isOpen && ticketId) {
      loadTicket();
    }
  }, [isOpen, ticketId]);

  const loadTicket = async () => {
    try {
      const { data, error } = await supabase
        .from('tickets')
        .select(`
          *,
          customers!tickets_customer_id_fkey(name, phone, address, city, state),
          profiles!tickets_assigned_to_fkey(full_name),
          equipment(model_number, manufacturer, equipment_type, serial_number)
        `)
        .eq('id', ticketId)
        .maybeSingle();

      if (error) throw error;
      if (data) {
        setTicket(data);
        setHoursOnsite(data.hours_onsite?.toString() || '');
        setStatus(data.status);
      }
    } catch (error) {
      console.error('Error loading ticket:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleUpdate = async () => {
    if (!ticket) return;

    setSaving(true);
    try {
      const updates: any = {
        status,
        hours_onsite: hoursOnsite ? parseFloat(hoursOnsite) : null,
      };

      if (status === 'completed' && !ticket.completed_date) {
        updates.completed_date = new Date().toISOString();
      }

      const { error } = await supabase
        .from('tickets')
        .update(updates)
        .eq('id', ticketId)
        .select()
        .single();

      if (error) {
        console.error('Error updating ticket:', error);

        let errorMessage = 'Failed to update ticket. Please try again.';

        if (error.message) {
          if (error.message.includes('permission denied') || error.message.includes('policy') || error.message.includes('Row level security')) {
            errorMessage = 'You do not have permission to update this ticket. Please contact your administrator.';
          } else if (error.message.includes('JSON object requested, multiple') || error.message.includes('0 rows')) {
            errorMessage = 'You do not have permission to update this ticket. Please contact your administrator.';
          } else if (error.message.includes('Cannot change status of billed ticket')) {
            errorMessage = 'Cannot change status of billed ticket. Invoice must be voided first.';
          } else if (error.message.includes('Cannot mark non-billable ticket')) {
            errorMessage = 'Cannot mark non-billable ticket as ready to invoice.';
          } else if (error.code === '23502') {
            errorMessage = 'Missing required field. Please ensure all required fields are filled.';
          } else if (error.code === '23503') {
            errorMessage = 'Invalid reference. Please check that all linked records exist.';
          } else if (error.code === 'PGRST116') {
            errorMessage = 'You do not have permission to update this ticket. Please contact your administrator.';
          } else {
            errorMessage = `Error: ${error.message}`;
          }
        }

        alert(errorMessage);
        return;
      }

      onUpdate();
      onClose();
    } catch (error: any) {
      console.error('Error updating ticket:', error);
      const errorMessage = error?.message || 'Failed to update ticket. Please try again.';
      alert(errorMessage);
    } finally {
      setSaving(false);
    }
  };

  const getStatusColor = (status: string) => {
    const colors: Record<string, string> = {
      open: 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400',
      scheduled: 'bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400',
      in_progress: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400',
      completed: 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400',
      cancelled: 'bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-400',
    };
    return colors[status] || colors.open;
  };

  const getPriorityColor = (priority: string) => {
    const colors: Record<string, string> = {
      urgent: 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400',
      high: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400',
      normal: 'bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400',
      low: 'bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-400',
    };
    return colors[priority] || colors.normal;
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white dark:bg-gray-800 rounded-lg max-w-3xl w-full max-h-[90vh] overflow-y-auto">
        <div className="sticky top-0 bg-white dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700 px-6 py-4 flex items-center justify-between">
          <h2 className="text-xl font-bold text-gray-900 dark:text-white">Ticket Details</h2>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg transition-colors"
          >
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>

        {loading ? (
          <div className="flex items-center justify-center p-12">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
          </div>
        ) : ticket ? (
          <div className="p-6 space-y-6">
            <div className="flex items-start justify-between">
              <div>
                <h3 className="text-2xl font-bold text-gray-900 dark:text-white">
                  {ticket.ticket_number}
                </h3>
                <p className="text-gray-600 dark:text-gray-400 mt-1">{ticket.title}</p>
              </div>
              <div className="flex items-center space-x-2">
                <span className={`badge ${getPriorityColor(ticket.priority)}`}>
                  {ticket.priority}
                </span>
                <span className={`badge ${getStatusColor(ticket.status)}`}>
                  {ticket.status.replace('_', ' ')}
                </span>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="space-y-4">
                <div>
                  <h4 className="text-sm font-medium text-gray-500 dark:text-gray-400 mb-2 flex items-center">
                    <User className="w-4 h-4 mr-2" />
                    Customer
                  </h4>
                  <div className="bg-gray-50 dark:bg-gray-700/50 rounded-lg p-3">
                    <p className="font-medium text-gray-900 dark:text-white">
                      {ticket.customers?.name || 'N/A'}
                    </p>
                    <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
                      {ticket.customers?.phone || 'No phone'}
                    </p>
                    <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
                      {ticket.customers?.address && `${ticket.customers.address}, ${ticket.customers.city}, ${ticket.customers.state}`}
                    </p>
                  </div>
                </div>

                <div>
                  <h4 className="text-sm font-medium text-gray-500 dark:text-gray-400 mb-2 flex items-center">
                    <Wrench className="w-4 h-4 mr-2" />
                    Equipment
                  </h4>
                  <div className="bg-gray-50 dark:bg-gray-700/50 rounded-lg p-3">
                    {ticket.equipment ? (
                      <>
                        <p className="font-medium text-gray-900 dark:text-white">
                          {ticket.equipment.manufacturer} {ticket.equipment.model_number}
                        </p>
                        <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
                          Type: {ticket.equipment.equipment_type}
                        </p>
                        <p className="text-sm text-gray-600 dark:text-gray-400">
                          S/N: {ticket.equipment.serial_number}
                        </p>
                      </>
                    ) : (
                      <p className="text-gray-600 dark:text-gray-400">No equipment assigned</p>
                    )}
                  </div>
                </div>
              </div>

              <div className="space-y-4">
                <div>
                  <h4 className="text-sm font-medium text-gray-500 dark:text-gray-400 mb-2 flex items-center">
                    <User className="w-4 h-4 mr-2" />
                    Assigned Technician
                  </h4>
                  <div className="bg-gray-50 dark:bg-gray-700/50 rounded-lg p-3">
                    <p className="text-gray-900 dark:text-white">
                      {ticket.profiles?.full_name || 'Unassigned'}
                    </p>
                  </div>
                </div>

                <div>
                  <h4 className="text-sm font-medium text-gray-500 dark:text-gray-400 mb-2 flex items-center">
                    <Calendar className="w-4 h-4 mr-2" />
                    Schedule
                  </h4>
                  <div className="bg-gray-50 dark:bg-gray-700/50 rounded-lg p-3">
                    <p className="text-sm text-gray-600 dark:text-gray-400">
                      Scheduled:{' '}
                      {ticket.scheduled_date
                        ? new Date(ticket.scheduled_date).toLocaleString()
                        : 'Not scheduled'}
                    </p>
                    {ticket.completed_date && (
                      <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
                        Completed: {new Date(ticket.completed_date).toLocaleString()}
                      </p>
                    )}
                  </div>
                </div>

                <div>
                  <h4 className="text-sm font-medium text-gray-500 dark:text-gray-400 mb-2 flex items-center">
                    <Wrench className="w-4 h-4 mr-2" />
                    Service Type
                  </h4>
                  <div className="bg-gray-50 dark:bg-gray-700/50 rounded-lg p-3">
                    <p className="text-gray-900 dark:text-white">{ticket.service_type}</p>
                  </div>
                </div>
              </div>
            </div>

            <div>
              <h4 className="text-sm font-medium text-gray-500 dark:text-gray-400 mb-2 flex items-center">
                <AlertCircle className="w-4 h-4 mr-2" />
                Description
              </h4>
              <div className="bg-gray-50 dark:bg-gray-700/50 rounded-lg p-3">
                <p className="text-gray-900 dark:text-white whitespace-pre-wrap">
                  {ticket.description}
                </p>
              </div>
            </div>

            <div className="border-t border-gray-200 dark:border-gray-700 pt-6">
              <h4 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">
                Update Ticket
              </h4>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Status
                  </label>
                  <select
                    value={status}
                    onChange={(e) => setStatus(e.target.value)}
                    className="input"
                  >
                    <option value="open">Open</option>
                    <option value="scheduled">Scheduled</option>
                    <option value="in_progress">In Progress</option>
                    <option value="completed">Completed</option>
                    <option value="cancelled">Cancelled</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1 flex items-center">
                    <Clock className="w-4 h-4 mr-2" />
                    Hours On-Site
                  </label>
                  <input
                    type="number"
                    step="0.25"
                    min="0"
                    placeholder="e.g., 2.5"
                    value={hoursOnsite}
                    onChange={(e) => setHoursOnsite(e.target.value)}
                    className="input"
                  />
                  <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                    Time spent on-site (in hours)
                  </p>
                </div>
              </div>
            </div>

            <div className="flex items-center justify-end space-x-3 pt-4 border-t border-gray-200 dark:border-gray-700">
              <button
                type="button"
                onClick={onClose}
                className="px-4 py-2 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleUpdate}
                disabled={saving}
                className="btn btn-primary"
              >
                {saving ? 'Saving...' : 'Save Changes'}
              </button>
            </div>
          </div>
        ) : (
          <div className="p-12 text-center text-gray-600 dark:text-gray-400">
            Ticket not found
          </div>
        )}
      </div>
    </div>
  );
}

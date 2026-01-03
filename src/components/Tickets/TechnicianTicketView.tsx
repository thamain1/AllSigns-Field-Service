import { useEffect, useState } from 'react';
import { Camera, Package, MessageSquare, CheckCircle, Clock, AlertTriangle, MapPin, Phone, User, Plus, X, Upload } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../contexts/AuthContext';

type Ticket = {
  id: string;
  ticket_number: string;
  title: string;
  description: string;
  status: string;
  priority: string;
  scheduled_date: string;
  hours_onsite: number;
  customers: {
    name: string;
    phone: string;
    email: string;
    address: string;
  };
  equipment: {
    equipment_type: string;
    model_number: string;
  } | null;
};

type TicketUpdate = {
  id: string;
  update_type: string;
  notes: string;
  progress_percent: number;
  created_at: string;
  profiles: {
    full_name: string;
  };
};

type TicketPhoto = {
  id: string;
  photo_url: string;
  photo_type: string;
  caption: string;
  created_at: string;
};

type PartUsed = {
  id: string;
  quantity: number;
  notes: string;
  created_at: string;
  parts: {
    part_number: string;
    name: string;
    unit_price: number;
  };
};

type Part = {
  id: string;
  part_number: string;
  name: string;
  unit_price: number;
};

export function TechnicianTicketView() {
  const { profile } = useAuth();
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [selectedTicket, setSelectedTicket] = useState<Ticket | null>(null);
  const [loading, setLoading] = useState(true);
  const [updates, setUpdates] = useState<TicketUpdate[]>([]);
  const [photos, setPhotos] = useState<TicketPhoto[]>([]);
  const [partsUsed, setPartsUsed] = useState<PartUsed[]>([]);
  const [availableParts, setAvailableParts] = useState<Part[]>([]);

  const [showUpdateModal, setShowUpdateModal] = useState(false);
  const [showPartsModal, setShowPartsModal] = useState(false);
  const [showPhotoModal, setShowPhotoModal] = useState(false);

  const [updateFormData, setUpdateFormData] = useState({
    update_type: 'progress_note' as const,
    notes: '',
    progress_percent: 0,
    status: '',
  });

  const [partsFormData, setPartsFormData] = useState({
    part_id: '',
    quantity: 1,
    notes: '',
  });

  const [photoFormData, setPhotoFormData] = useState({
    photo_url: '',
    photo_type: 'during' as const,
    caption: '',
  });

  const [uploadingPhoto, setUploadingPhoto] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);

  useEffect(() => {
    loadMyTickets();
  }, []);

  useEffect(() => {
    if (selectedTicket) {
      console.log('Selected ticket changed, loading details for:', selectedTicket.id);
      loadTicketDetails(selectedTicket.id);
    } else {
      console.log('No ticket selected');
    }
  }, [selectedTicket]);

  const loadMyTickets = async () => {
    try {
      const { data, error } = await supabase
        .from('tickets')
        .select('*, customers!tickets_customer_id_fkey(name, phone, email, address), equipment(equipment_type, model_number)')
        .eq('assigned_to', profile?.id)
        .in('status', ['open', 'scheduled', 'in_progress'])
        .order('scheduled_date', { ascending: true });

      if (error) throw error;
      console.log('Loaded tickets:', data?.length || 0);
      setTickets(data || []);
    } catch (error) {
      console.error('Error loading tickets:', error);
      alert('Error loading tickets: ' + (error as Error).message);
    } finally {
      setLoading(false);
    }
  };

  const loadTicketDetails = async (ticketId: string) => {
    console.log('Loading ticket details for:', ticketId);
    try {
      const [updatesRes, photosRes, partsRes, availablePartsRes] = await Promise.all([
        supabase
          .from('ticket_updates')
          .select('*, profiles(full_name)')
          .eq('ticket_id', ticketId)
          .order('created_at', { ascending: false }),
        supabase
          .from('ticket_photos')
          .select('*')
          .eq('ticket_id', ticketId)
          .order('created_at', { ascending: false }),
        supabase
          .from('ticket_parts_used')
          .select('*, parts(part_number, name, unit_price)')
          .eq('ticket_id', ticketId)
          .order('created_at', { ascending: false }),
        supabase
          .from('parts')
          .select('id, part_number, name, unit_price')
          .order('name', { ascending: true }),
      ]);

      if (updatesRes.error) throw updatesRes.error;
      if (photosRes.error) throw photosRes.error;
      if (partsRes.error) throw partsRes.error;
      if (availablePartsRes.error) throw availablePartsRes.error;

      console.log('Updates loaded:', updatesRes.data?.length || 0);
      console.log('Photos loaded:', photosRes.data?.length || 0);
      console.log('Parts used loaded:', partsRes.data?.length || 0);
      console.log('Available parts loaded:', availablePartsRes.data?.length || 0);

      setUpdates(updatesRes.data || []);
      setPhotos(photosRes.data || []);
      setPartsUsed(partsRes.data || []);
      setAvailableParts(availablePartsRes.data || []);
    } catch (error) {
      console.error('Error loading ticket details:', error);
      alert('Error loading ticket details: ' + (error as Error).message);
    }
  };

  const handleAddUpdate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedTicket) return;

    try {
      // Get current user ID
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        throw new Error('User not authenticated');
      }

      console.log('Adding update for ticket:', selectedTicket.id);
      console.log('User ID:', user.id);
      console.log('Update data:', updateFormData);

      const updateData: any = {
        ticket_id: selectedTicket.id,
        technician_id: user.id,
        update_type: updateFormData.update_type,
        notes: updateFormData.notes,
        progress_percent: updateFormData.progress_percent,
      };

      // Only include status if it's not empty
      if (updateFormData.status && updateFormData.status !== '') {
        updateData.status = updateFormData.status;
      }

      const { error: updateError } = await supabase.from('ticket_updates').insert([updateData]);

      if (updateError) {
        console.error('Error inserting update:', updateError);
        throw updateError;
      }

      if (updateFormData.status) {
        const { error: ticketError } = await supabase
          .from('tickets')
          .update({
            status: updateFormData.status,
            updated_at: new Date().toISOString(),
            assigned_to: selectedTicket.assigned_to
          })
          .eq('id', selectedTicket.id);

        if (ticketError) {
          console.error('Error updating ticket status:', ticketError);
          throw ticketError;
        }
      }

      // Reload data before closing modal
      await loadTicketDetails(selectedTicket.id);
      await loadMyTickets();

      setShowUpdateModal(false);
      setUpdateFormData({
        update_type: 'progress_note',
        notes: '',
        progress_percent: 0,
        status: '',
      });
    } catch (error) {
      console.error('Error adding update:', error);
      let errorMessage = 'Unknown error';
      if (error instanceof Error) {
        errorMessage = error.message;
      } else if (error && typeof error === 'object' && 'message' in error) {
        errorMessage = (error as any).message;
      } else if (typeof error === 'string') {
        errorMessage = error;
      }
      alert('Failed to add update: ' + errorMessage);
    }
  };

  const handleAddPart = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedTicket) return;

    try {
      const { error } = await supabase.from('ticket_parts_used').insert([{
        ticket_id: selectedTicket.id,
        part_id: partsFormData.part_id,
        quantity: partsFormData.quantity,
        installed_by: profile?.id,
        notes: partsFormData.notes,
      }]);

      if (error) throw error;

      // Reload data before closing modal
      await loadTicketDetails(selectedTicket.id);

      setShowPartsModal(false);
      setPartsFormData({
        part_id: '',
        quantity: 1,
        notes: '',
      });
    } catch (error) {
      console.error('Error adding part:', error);
      alert('Failed to add part. Please try again.');
    }
  };

  const handlePhotoUpload = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedTicket) return;
    if (!selectedFile) {
      alert('Please select a photo to upload');
      return;
    }

    setUploadingPhoto(true);

    try {
      const fileExt = selectedFile.name.split('.').pop();
      const fileName = `${selectedTicket.id}/${Date.now()}.${fileExt}`;

      console.log('Uploading file:', fileName, 'Size:', selectedFile.size, 'Type:', selectedFile.type);

      const { data: uploadData, error: uploadError } = await supabase.storage
        .from('ticket-photos')
        .upload(fileName, selectedFile, {
          cacheControl: '3600',
          upsert: false
        });

      if (uploadError) {
        console.error('Upload error details:', uploadError);
        throw uploadError;
      }

      console.log('Upload successful:', uploadData);

      const { data: urlData } = supabase.storage
        .from('ticket-photos')
        .getPublicUrl(fileName);

      console.log('Public URL:', urlData.publicUrl);

      // Ensure photo_type has a valid value
      const photoType = photoFormData.photo_type || 'during';
      const validPhotoTypes = ['before', 'during', 'after', 'issue', 'equipment', 'other'];
      if (!validPhotoTypes.includes(photoType)) {
        throw new Error(`Invalid photo_type: ${photoType}`);
      }

      console.log('Inserting record with photo_type:', photoType);

      const { error } = await supabase.from('ticket_photos').insert([{
        ticket_id: selectedTicket.id,
        uploaded_by: profile?.id,
        photo_url: urlData.publicUrl,
        photo_type: photoType,
        caption: photoFormData.caption || null,
      }]);

      if (error) {
        console.error('Database insert error:', error);
        throw error;
      }

      // Reload data before closing modal
      await loadTicketDetails(selectedTicket.id);

      setShowPhotoModal(false);
      setPhotoFormData({
        photo_url: '',
        photo_type: 'during',
        caption: '',
      });
      setSelectedFile(null);
      alert('Photo uploaded successfully!');
    } catch (error: any) {
      console.error('Error uploading photo:', error);
      const errorMessage = error?.message || 'Unknown error occurred';
      alert(`Failed to upload photo: ${errorMessage}`);
    } finally {
      setUploadingPhoto(false);
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'open': return 'badge-blue';
      case 'scheduled': return 'badge-blue';
      case 'in_progress': return 'badge-yellow';
      case 'completed': return 'badge-green';
      case 'cancelled': return 'badge-gray';
      default: return 'badge-gray';
    }
  };

  const getPriorityColor = (priority: string) => {
    switch (priority) {
      case 'urgent': return 'text-red-600';
      case 'high': return 'text-orange-600';
      case 'normal': return 'text-blue-600';
      case 'low': return 'text-gray-600';
      default: return 'text-gray-600';
    }
  };

  const getUpdateTypeIcon = (type: string) => {
    switch (type) {
      case 'arrived': return <MapPin className="w-5 h-5 text-blue-600" />;
      case 'completed': return <CheckCircle className="w-5 h-5 text-green-600" />;
      case 'needs_parts': return <Package className="w-5 h-5 text-orange-600" />;
      case 'issue': return <AlertTriangle className="w-5 h-5 text-red-600" />;
      default: return <MessageSquare className="w-5 h-5 text-gray-600" />;
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  if (selectedTicket) {
    return (
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-4">
            <button
              onClick={() => setSelectedTicket(null)}
              className="btn btn-outline"
            >
              ← Back to My Tickets
            </button>
            <div>
              <h1 className="text-2xl font-bold text-gray-900 dark:text-white">
                {selectedTicket.ticket_number}
              </h1>
              <p className="text-gray-600 dark:text-gray-400">{selectedTicket.title}</p>
            </div>
          </div>
          <span className={`badge ${getStatusColor(selectedTicket.status)}`}>
            {selectedTicket.status.replace('_', ' ')}
          </span>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2 space-y-6">
            <div className="card p-6">
              <h2 className="text-lg font-bold text-gray-900 dark:text-white mb-4">Job Details</h2>
              <div className="space-y-3">
                <div>
                  <p className="text-sm text-gray-600 dark:text-gray-400">Description</p>
                  <p className="text-gray-900 dark:text-white">{selectedTicket.description}</p>
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <p className="text-sm text-gray-600 dark:text-gray-400">Scheduled</p>
                    <p className="text-gray-900 dark:text-white">
                      {new Date(selectedTicket.scheduled_date).toLocaleString()}
                    </p>
                  </div>
                  <div>
                    <p className="text-sm text-gray-600 dark:text-gray-400">Priority</p>
                    <p className={`font-medium ${getPriorityColor(selectedTicket.priority)}`}>
                      {selectedTicket.priority.toUpperCase()}
                    </p>
                  </div>
                </div>
                {selectedTicket.equipment && (
                  <div>
                    <p className="text-sm text-gray-600 dark:text-gray-400">Equipment</p>
                    <p className="text-gray-900 dark:text-white">
                      {selectedTicket.equipment.equipment_type} - {selectedTicket.equipment.model_number}
                    </p>
                  </div>
                )}
              </div>
            </div>

            <div className="card p-6">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-bold text-gray-900 dark:text-white">Updates</h2>
                <button
                  onClick={() => setShowUpdateModal(true)}
                  className="btn btn-primary flex items-center space-x-2"
                >
                  <Plus className="w-4 h-4" />
                  <span>Add Update</span>
                </button>
              </div>
              <div className="space-y-3">
                {updates.length === 0 ? (
                  <p className="text-gray-500 dark:text-gray-400 text-center py-8">No updates yet</p>
                ) : (
                  updates.map((update) => (
                    <div key={update.id} className="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
                      <div className="flex items-start space-x-3">
                        {getUpdateTypeIcon(update.update_type)}
                        <div className="flex-1">
                          <div className="flex items-center justify-between mb-1">
                            <span className="font-medium text-gray-900 dark:text-white">
                              {update.update_type.replace('_', ' ')}
                            </span>
                            <span className="text-sm text-gray-500 dark:text-gray-400">
                              {new Date(update.created_at).toLocaleString()}
                            </span>
                          </div>
                          <p className="text-gray-700 dark:text-gray-300">{update.notes}</p>
                          {update.progress_percent > 0 && (
                            <div className="mt-2">
                              <div className="flex items-center justify-between text-sm mb-1">
                                <span className="text-gray-600 dark:text-gray-400">Progress</span>
                                <span className="font-medium text-gray-900 dark:text-white">
                                  {update.progress_percent}%
                                </span>
                              </div>
                              <div className="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2">
                                <div
                                  className="bg-blue-600 h-2 rounded-full"
                                  style={{ width: `${update.progress_percent}%` }}
                                />
                              </div>
                            </div>
                          )}
                        </div>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>

            <div className="card p-6">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-bold text-gray-900 dark:text-white">Photos</h2>
                <button
                  onClick={() => setShowPhotoModal(true)}
                  className="btn btn-outline flex items-center space-x-2"
                >
                  <Camera className="w-4 h-4" />
                  <span>Add Photo</span>
                </button>
              </div>
              <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                {photos.length === 0 ? (
                  <p className="col-span-full text-gray-500 dark:text-gray-400 text-center py-8">
                    No photos yet
                  </p>
                ) : (
                  photos.map((photo) => (
                    <div key={photo.id} className="relative group">
                      <div className="aspect-square bg-gray-200 dark:bg-gray-700 rounded-lg overflow-hidden">
                        {photo.photo_url ? (
                          <img
                            src={photo.photo_url}
                            alt={photo.caption || 'Ticket photo'}
                            className="w-full h-full object-cover"
                          />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center">
                            <Camera className="w-12 h-12 text-gray-400" />
                          </div>
                        )}
                      </div>
                      <div className="mt-2">
                        <span className="text-xs badge badge-gray">{photo.photo_type}</span>
                        {photo.caption && (
                          <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
                            {photo.caption}
                          </p>
                        )}
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>

            <div className="card p-6">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-bold text-gray-900 dark:text-white">Parts Used</h2>
                <button
                  onClick={() => setShowPartsModal(true)}
                  className="btn btn-outline flex items-center space-x-2"
                >
                  <Package className="w-4 h-4" />
                  <span>Add Part</span>
                </button>
              </div>
              <div className="space-y-3">
                {partsUsed.length === 0 ? (
                  <p className="text-gray-500 dark:text-gray-400 text-center py-8">No parts used yet</p>
                ) : (
                  partsUsed.map((part) => (
                    <div key={part.id} className="flex items-center justify-between border-b border-gray-200 dark:border-gray-700 pb-3">
                      <div>
                        <p className="font-medium text-gray-900 dark:text-white">
                          {part.parts.name}
                        </p>
                        <p className="text-sm text-gray-600 dark:text-gray-400">
                          {part.parts.part_number} - Qty: {part.quantity}
                        </p>
                        {part.notes && (
                          <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">{part.notes}</p>
                        )}
                      </div>
                      <p className="font-medium text-gray-900 dark:text-white">
                        ${(part.parts.unit_price * part.quantity).toFixed(2)}
                      </p>
                    </div>
                  ))
                )}
              </div>
              {partsUsed.length > 0 && (
                <div className="mt-4 pt-4 border-t border-gray-200 dark:border-gray-700">
                  <div className="flex items-center justify-between font-bold">
                    <span className="text-gray-900 dark:text-white">Total Parts Cost</span>
                    <span className="text-gray-900 dark:text-white">
                      ${partsUsed.reduce((sum, p) => sum + (p.parts.unit_price * p.quantity), 0).toFixed(2)}
                    </span>
                  </div>
                </div>
              )}
            </div>
          </div>

          <div className="space-y-6">
            <div className="card p-6">
              <h2 className="text-lg font-bold text-gray-900 dark:text-white mb-4">Customer Info</h2>
              <div className="space-y-3">
                <div className="flex items-center space-x-3">
                  <User className="w-5 h-5 text-gray-400" />
                  <div>
                    <p className="text-sm text-gray-600 dark:text-gray-400">Name</p>
                    <p className="font-medium text-gray-900 dark:text-white">
                      {selectedTicket.customers.name}
                    </p>
                  </div>
                </div>
                <div className="flex items-center space-x-3">
                  <Phone className="w-5 h-5 text-gray-400" />
                  <div>
                    <p className="text-sm text-gray-600 dark:text-gray-400">Phone</p>
                    <a
                      href={`tel:${selectedTicket.customers.phone}`}
                      className="font-medium text-blue-600 hover:underline"
                    >
                      {selectedTicket.customers.phone}
                    </a>
                  </div>
                </div>
                <div className="flex items-center space-x-3">
                  <MapPin className="w-5 h-5 text-gray-400" />
                  <div>
                    <p className="text-sm text-gray-600 dark:text-gray-400">Address</p>
                    <p className="font-medium text-gray-900 dark:text-white">
                      {selectedTicket.customers.address}
                    </p>
                  </div>
                </div>
              </div>
            </div>

            <div className="card p-6">
              <h2 className="text-lg font-bold text-gray-900 dark:text-white mb-4">Time Tracking</h2>
              <div className="space-y-3 mb-6">
                <div className="flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-700 rounded-lg">
                  <span className="text-sm text-gray-600 dark:text-gray-400">Status</span>
                  <span className={`badge ${getStatusColor(selectedTicket.status)}`}>
                    {selectedTicket.status.replace('_', ' ')}
                  </span>
                </div>
                {selectedTicket.hours_onsite > 0 && (
                  <div className="flex items-center justify-between p-3 bg-blue-50 dark:bg-blue-900/20 rounded-lg">
                    <span className="text-sm text-gray-600 dark:text-gray-400">Billable Hours</span>
                    <span className="font-bold text-blue-600">
                      {selectedTicket.hours_onsite.toFixed(2)} hrs
                    </span>
                  </div>
                )}
              </div>

              <h2 className="text-lg font-bold text-gray-900 dark:text-white mb-4">Quick Actions</h2>
              <div className="space-y-3">
                {(selectedTicket.status === 'open' || selectedTicket.status === 'scheduled') && (
                  <button
                    onClick={async () => {
                      try {
                        const { error } = await supabase
                          .from('tickets')
                          .update({
                            status: 'in_progress',
                            updated_at: new Date().toISOString()
                          })
                          .eq('id', selectedTicket.id);

                        if (error) throw error;

                        await supabase.from('ticket_updates').insert([{
                          ticket_id: selectedTicket.id,
                          technician_id: profile?.id,
                          update_type: 'arrived',
                          notes: 'Arrived on site and started work',
                          progress_percent: 0,
                          status: 'in_progress',
                        }]);

                        // Reload data to show the new update
                        await loadMyTickets();
                        await loadTicketDetails(selectedTicket.id);
                      } catch (error) {
                        console.error('Error starting ticket:', error);
                        alert('Failed to start ticket. Please try again.');
                      }
                    }}
                    className="w-full btn btn-primary flex items-center justify-center space-x-2"
                  >
                    <Clock className="w-4 h-4" />
                    <span>Start Work (Begin Timer)</span>
                  </button>
                )}
                <button
                  onClick={() => {
                    setUpdateFormData({ ...updateFormData, update_type: 'needs_parts' });
                    setShowUpdateModal(true);
                  }}
                  className="w-full btn btn-outline flex items-center justify-center space-x-2"
                >
                  <Package className="w-4 h-4" />
                  <span>Need Parts</span>
                </button>
                <button
                  onClick={() => {
                    setUpdateFormData({ ...updateFormData, update_type: 'issue' });
                    setShowUpdateModal(true);
                  }}
                  className="w-full btn btn-outline flex items-center justify-center space-x-2"
                >
                  <AlertTriangle className="w-4 h-4" />
                  <span>Report Issue</span>
                </button>
                <button
                  onClick={() => {
                    setUpdateFormData({ ...updateFormData, update_type: 'completed', status: 'completed' });
                    setShowUpdateModal(true);
                  }}
                  className="w-full btn btn-primary flex items-center justify-center space-x-2"
                >
                  <CheckCircle className="w-4 h-4" />
                  <span>Mark Complete</span>
                </button>
              </div>
            </div>
          </div>
        </div>

        {showUpdateModal && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
            <div className="bg-white dark:bg-gray-800 rounded-xl shadow-2xl max-w-lg w-full">
              <div className="flex items-center justify-between p-6 border-b border-gray-200 dark:border-gray-700">
                <h2 className="text-xl font-bold text-gray-900 dark:text-white">Add Update</h2>
                <button onClick={() => setShowUpdateModal(false)} className="text-gray-400 hover:text-gray-600">
                  <X className="w-6 h-6" />
                </button>
              </div>

              <form onSubmit={handleAddUpdate} className="p-6 space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Update Type *
                  </label>
                  <select
                    required
                    value={updateFormData.update_type}
                    onChange={(e) => setUpdateFormData({ ...updateFormData, update_type: e.target.value as any })}
                    className="input"
                  >
                    <option value="progress_note">Progress Note</option>
                    <option value="arrived">Arrived On Site</option>
                    <option value="needs_parts">Needs Parts</option>
                    <option value="issue">Issue/Problem</option>
                    <option value="completed">Completed</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Notes *
                  </label>
                  <textarea
                    required
                    value={updateFormData.notes}
                    onChange={(e) => setUpdateFormData({ ...updateFormData, notes: e.target.value })}
                    className="input"
                    rows={4}
                    placeholder="Describe the update..."
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Progress %
                  </label>
                  <input
                    type="number"
                    min="0"
                    max="100"
                    value={updateFormData.progress_percent}
                    onChange={(e) => setUpdateFormData({ ...updateFormData, progress_percent: parseInt(e.target.value) || 0 })}
                    className="input"
                  />
                </div>

                {updateFormData.update_type === 'completed' && (
                  <div>
                    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                      New Status
                    </label>
                    <select
                      value={updateFormData.status}
                      onChange={(e) => setUpdateFormData({ ...updateFormData, status: e.target.value })}
                      className="input"
                    >
                      <option value="">Keep Current</option>
                      <option value="in_progress">In Progress</option>
                      <option value="completed">Completed</option>
                    </select>
                  </div>
                )}

                <div className="flex space-x-3 pt-4">
                  <button type="button" onClick={() => setShowUpdateModal(false)} className="btn btn-outline flex-1">
                    Cancel
                  </button>
                  <button type="submit" className="btn btn-primary flex-1">
                    Add Update
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {showPartsModal && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
            <div className="bg-white dark:bg-gray-800 rounded-xl shadow-2xl max-w-lg w-full">
              <div className="flex items-center justify-between p-6 border-b border-gray-200 dark:border-gray-700">
                <h2 className="text-xl font-bold text-gray-900 dark:text-white">Add Part Used</h2>
                <button onClick={() => setShowPartsModal(false)} className="text-gray-400 hover:text-gray-600">
                  <X className="w-6 h-6" />
                </button>
              </div>

              <form onSubmit={handleAddPart} className="p-6 space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Part *
                  </label>
                  <select
                    required
                    value={partsFormData.part_id}
                    onChange={(e) => setPartsFormData({ ...partsFormData, part_id: e.target.value })}
                    className="input"
                  >
                    <option value="">Select Part</option>
                    {availableParts.map((part) => (
                      <option key={part.id} value={part.id}>
                        {part.part_number} - {part.name} (${part.unit_price})
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Quantity *
                  </label>
                  <input
                    type="number"
                    required
                    min="0.01"
                    step="0.01"
                    value={partsFormData.quantity}
                    onChange={(e) => setPartsFormData({ ...partsFormData, quantity: parseFloat(e.target.value) || 1 })}
                    className="input"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Notes
                  </label>
                  <textarea
                    value={partsFormData.notes}
                    onChange={(e) => setPartsFormData({ ...partsFormData, notes: e.target.value })}
                    className="input"
                    rows={2}
                    placeholder="Installation notes..."
                  />
                </div>

                <div className="flex space-x-3 pt-4">
                  <button type="button" onClick={() => setShowPartsModal(false)} className="btn btn-outline flex-1">
                    Cancel
                  </button>
                  <button type="submit" className="btn btn-primary flex-1">
                    Add Part
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {showPhotoModal && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
            <div className="bg-white dark:bg-gray-800 rounded-xl shadow-2xl max-w-lg w-full">
              <div className="flex items-center justify-between p-6 border-b border-gray-200 dark:border-gray-700">
                <h2 className="text-xl font-bold text-gray-900 dark:text-white">Add Photo</h2>
                <button onClick={() => setShowPhotoModal(false)} className="text-gray-400 hover:text-gray-600">
                  <X className="w-6 h-6" />
                </button>
              </div>

              <form onSubmit={handlePhotoUpload} className="p-6 space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Photo Type *
                  </label>
                  <select
                    required
                    value={photoFormData.photo_type}
                    onChange={(e) => setPhotoFormData({ ...photoFormData, photo_type: e.target.value as any })}
                    className="input"
                  >
                    <option value="before">Before</option>
                    <option value="during">During Work</option>
                    <option value="after">After</option>
                    <option value="issue">Issue/Problem</option>
                    <option value="equipment">Equipment</option>
                    <option value="other">Other</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Select Photo *
                  </label>
                  <div className="mt-1">
                    <input
                      type="file"
                      accept="image/*"
                      onChange={(e) => setSelectedFile(e.target.files?.[0] || null)}
                      className="block w-full text-sm text-gray-900 dark:text-white
                        file:mr-4 file:py-2 file:px-4
                        file:rounded-lg file:border-0
                        file:text-sm file:font-semibold
                        file:bg-blue-50 file:text-blue-700
                        hover:file:bg-blue-100
                        dark:file:bg-blue-900/20 dark:file:text-blue-400
                        cursor-pointer"
                    />
                  </div>
                  {selectedFile && (
                    <p className="text-sm text-gray-600 dark:text-gray-400 mt-2">
                      Selected: {selectedFile.name} ({(selectedFile.size / 1024 / 1024).toFixed(2)} MB)
                    </p>
                  )}
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Caption
                  </label>
                  <input
                    type="text"
                    value={photoFormData.caption}
                    onChange={(e) => setPhotoFormData({ ...photoFormData, caption: e.target.value })}
                    className="input"
                    placeholder="Photo description..."
                  />
                </div>

                <div className="flex space-x-3 pt-4">
                  <button
                    type="button"
                    onClick={() => {
                      setShowPhotoModal(false);
                      setSelectedFile(null);
                    }}
                    className="btn btn-outline flex-1"
                    disabled={uploadingPhoto}
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    className="btn btn-primary flex-1"
                    disabled={uploadingPhoto || !selectedFile}
                  >
                    {uploadingPhoto ? 'Uploading...' : 'Upload Photo'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-gray-900 dark:text-white">My Tickets</h1>
        <p className="text-gray-600 dark:text-gray-400 mt-1">
          Your assigned service tickets
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {tickets.length === 0 ? (
          <div className="col-span-full card p-12 text-center">
            <Clock className="w-16 h-16 text-gray-400 mx-auto mb-4" />
            <p className="text-gray-600 dark:text-gray-400">No active tickets assigned</p>
          </div>
        ) : (
          tickets.map((ticket) => (
            <div
              key={ticket.id}
              onClick={() => setSelectedTicket(ticket)}
              className="card p-6 hover:shadow-lg transition-shadow cursor-pointer"
            >
              <div className="flex items-start justify-between mb-3">
                <div>
                  <p className="text-sm text-gray-600 dark:text-gray-400">{ticket.ticket_number}</p>
                  <h3 className="text-lg font-bold text-gray-900 dark:text-white mt-1">
                    {ticket.title}
                  </h3>
                </div>
                <span className={`badge ${getStatusColor(ticket.status)}`}>
                  {ticket.status.replace('_', ' ')}
                </span>
              </div>

              <div className="space-y-2 mb-4">
                <div className="flex items-center space-x-2 text-sm">
                  <User className="w-4 h-4 text-gray-400" />
                  <span className="text-gray-900 dark:text-white">{ticket.customers.name}</span>
                </div>
                <div className="flex items-center space-x-2 text-sm">
                  <MapPin className="w-4 h-4 text-gray-400" />
                  <span className="text-gray-900 dark:text-white">{ticket.customers.address}</span>
                </div>
                <div className="flex items-center space-x-2 text-sm">
                  <Clock className="w-4 h-4 text-gray-400" />
                  <span className="text-gray-900 dark:text-white">
                    {new Date(ticket.scheduled_date).toLocaleString()}
                  </span>
                </div>
              </div>

              <div className="pt-3 border-t border-gray-200 dark:border-gray-700">
                <span className={`text-sm font-medium ${getPriorityColor(ticket.priority)}`}>
                  {ticket.priority.toUpperCase()} PRIORITY
                </span>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

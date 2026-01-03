export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type UserRole = 'admin' | 'dispatcher' | 'technician';
export type TicketStatus = 'open' | 'scheduled' | 'in_progress' | 'completed' | 'cancelled';
export type TicketPriority = 'low' | 'normal' | 'high' | 'urgent';
export type NoteType = 'general' | 'diagnostic' | 'customer' | 'internal';
export type LocationType = 'main_warehouse' | 'vehicle' | 'customer_site';

export interface Database {
  public: {
    Tables: {
      profiles: {
        Row: {
          id: string;
          email: string;
          full_name: string;
          role: UserRole;
          phone: string | null;
          avatar_url: string | null;
          is_active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id: string;
          email: string;
          full_name: string;
          role?: UserRole;
          phone?: string | null;
          avatar_url?: string | null;
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          email?: string;
          full_name?: string;
          role?: UserRole;
          phone?: string | null;
          avatar_url?: string | null;
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
        };
      };
      customers: {
        Row: {
          id: string;
          name: string;
          email: string | null;
          phone: string | null;
          address: string | null;
          city: string | null;
          state: string | null;
          zip_code: string | null;
          notes: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          name: string;
          email?: string | null;
          phone?: string | null;
          address?: string | null;
          city?: string | null;
          state?: string | null;
          zip_code?: string | null;
          notes?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          name?: string;
          email?: string | null;
          phone?: string | null;
          address?: string | null;
          city?: string | null;
          state?: string | null;
          zip_code?: string | null;
          notes?: string | null;
          created_at?: string;
          updated_at?: string;
        };
      };
      parts: {
        Row: {
          id: string;
          part_number: string;
          name: string;
          description: string | null;
          manufacturer: string | null;
          category: string | null;
          quantity_on_hand: number;
          unit_price: number;
          location: string | null;
          reorder_level: number;
          warranty_period_months: number | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          part_number: string;
          name: string;
          description?: string | null;
          manufacturer?: string | null;
          category?: string | null;
          quantity_on_hand?: number;
          unit_price?: number;
          location?: string | null;
          reorder_level?: number;
          warranty_period_months?: number | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          part_number?: string;
          name?: string;
          description?: string | null;
          manufacturer?: string | null;
          category?: string | null;
          quantity_on_hand?: number;
          unit_price?: number;
          location?: string | null;
          reorder_level?: number;
          warranty_period_months?: number | null;
          created_at?: string;
          updated_at?: string;
        };
      };
      equipment: {
        Row: {
          id: string;
          customer_id: string | null;
          serial_number: string;
          model_number: string;
          manufacturer: string;
          equipment_type: string;
          installation_date: string | null;
          warranty_expiration: string | null;
          warranty_status: string | null;
          location: string | null;
          notes: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          customer_id?: string | null;
          serial_number: string;
          model_number: string;
          manufacturer: string;
          equipment_type: string;
          installation_date?: string | null;
          warranty_expiration?: string | null;
          warranty_status?: string | null;
          location?: string | null;
          notes?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          customer_id?: string | null;
          serial_number?: string;
          model_number?: string;
          manufacturer?: string;
          equipment_type?: string;
          installation_date?: string | null;
          warranty_expiration?: string | null;
          warranty_status?: string | null;
          location?: string | null;
          notes?: string | null;
          created_at?: string;
          updated_at?: string;
        };
      };
      tickets: {
        Row: {
          id: string;
          ticket_number: string;
          customer_id: string;
          equipment_id: string | null;
          assigned_to: string | null;
          status: TicketStatus;
          priority: TicketPriority;
          title: string;
          description: string | null;
          service_type: string | null;
          scheduled_date: string | null;
          completed_date: string | null;
          created_by: string;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          ticket_number: string;
          customer_id: string;
          equipment_id?: string | null;
          assigned_to?: string | null;
          status?: TicketStatus;
          priority?: TicketPriority;
          title: string;
          description?: string | null;
          service_type?: string | null;
          scheduled_date?: string | null;
          completed_date?: string | null;
          created_by: string;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          ticket_number?: string;
          customer_id?: string;
          equipment_id?: string | null;
          assigned_to?: string | null;
          status?: TicketStatus;
          priority?: TicketPriority;
          title?: string;
          description?: string | null;
          service_type?: string | null;
          scheduled_date?: string | null;
          completed_date?: string | null;
          created_by?: string;
          created_at?: string;
          updated_at?: string;
        };
      };
      ticket_notes: {
        Row: {
          id: string;
          ticket_id: string;
          created_by: string;
          note_type: NoteType;
          content: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          ticket_id: string;
          created_by: string;
          note_type?: NoteType;
          content: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          ticket_id?: string;
          created_by?: string;
          note_type?: NoteType;
          content?: string;
          created_at?: string;
        };
      };
      ticket_photos: {
        Row: {
          id: string;
          ticket_id: string;
          uploaded_by: string;
          photo_url: string;
          caption: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          ticket_id: string;
          uploaded_by: string;
          photo_url: string;
          caption?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          ticket_id?: string;
          uploaded_by?: string;
          photo_url?: string;
          caption?: string | null;
          created_at?: string;
        };
      };
      parts_usage: {
        Row: {
          id: string;
          ticket_id: string;
          part_id: string;
          quantity_used: number;
          recorded_by: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          ticket_id: string;
          part_id: string;
          quantity_used?: number;
          recorded_by: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          ticket_id?: string;
          part_id?: string;
          quantity_used?: number;
          recorded_by?: string;
          created_at?: string;
        };
      };
      technician_locations: {
        Row: {
          id: string;
          technician_id: string;
          latitude: number;
          longitude: number;
          accuracy: number | null;
          timestamp: string;
        };
        Insert: {
          id?: string;
          technician_id: string;
          latitude: number;
          longitude: number;
          accuracy?: number | null;
          timestamp?: string;
        };
        Update: {
          id?: string;
          technician_id?: string;
          latitude?: number;
          longitude?: number;
          accuracy?: number | null;
          timestamp?: string;
        };
      };
      activity_log: {
        Row: {
          id: string;
          user_id: string | null;
          action: string;
          entity_type: string;
          entity_id: string | null;
          details: Json | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          user_id?: string | null;
          action: string;
          entity_type: string;
          entity_id?: string | null;
          details?: Json | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          user_id?: string | null;
          action?: string;
          entity_type?: string;
          entity_id?: string | null;
          details?: Json | null;
          created_at?: string;
        };
      };
      warehouse_locations: {
        Row: {
          id: string;
          name: string;
          location_type: LocationType;
          vehicle_id: string | null;
          technician_id: string | null;
          address: string | null;
          is_active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          name: string;
          location_type: LocationType;
          vehicle_id?: string | null;
          technician_id?: string | null;
          address?: string | null;
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          name?: string;
          location_type?: LocationType;
          vehicle_id?: string | null;
          technician_id?: string | null;
          address?: string | null;
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
        };
      };
      part_inventory: {
        Row: {
          id: string;
          part_id: string;
          warehouse_location_id: string;
          quantity: number;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          part_id: string;
          warehouse_location_id: string;
          quantity?: number;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          part_id?: string;
          warehouse_location_id?: string;
          quantity?: number;
          created_at?: string;
          updated_at?: string;
        };
      };
      customer_parts_installed: {
        Row: {
          id: string;
          customer_id: string;
          part_id: string;
          equipment_id: string | null;
          ticket_id: string | null;
          quantity: number;
          installation_date: string;
          installed_by: string | null;
          location_notes: string | null;
          warranty_expiration: string | null;
          notes: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          customer_id: string;
          part_id: string;
          equipment_id?: string | null;
          ticket_id?: string | null;
          quantity?: number;
          installation_date?: string;
          installed_by?: string | null;
          location_notes?: string | null;
          warranty_expiration?: string | null;
          notes?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          customer_id?: string;
          part_id?: string;
          equipment_id?: string | null;
          ticket_id?: string | null;
          quantity?: number;
          installation_date?: string;
          installed_by?: string | null;
          location_notes?: string | null;
          warranty_expiration?: string | null;
          notes?: string | null;
          created_at?: string;
          updated_at?: string;
        };
      };
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      [_ in never]: never;
    };
    Enums: {
      user_role: UserRole;
      ticket_status: TicketStatus;
      ticket_priority: TicketPriority;
      note_type: NoteType;
      location_type: LocationType;
    };
  };
}

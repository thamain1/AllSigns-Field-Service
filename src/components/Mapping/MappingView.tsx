import { useEffect, useState } from 'react';
import { Map, MapPin, Navigation, Filter } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import type { Database } from '../../lib/database.types';

type Ticket = Database['public']['Tables']['tickets']['Row'] & {
  customers?: { name: string; address: string; city: string; state: string };
  profiles?: { full_name: string };
};

export function MappingView() {
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState<string>('all');

  useEffect(() => {
    loadTickets();
  }, []);

  const loadTickets = async () => {
    try {
      const { data, error } = await supabase
        .from('tickets')
        .select('*, customers!tickets_customer_id_fkey(name, address, city, state), profiles!tickets_assigned_to_fkey(full_name)')
        .neq('status', 'cancelled')
        .order('priority', { ascending: false });

      if (error) throw error;
      setTickets(data || []);
    } catch (error) {
      console.error('Error loading tickets:', error);
    } finally {
      setLoading(false);
    }
  };

  const filteredTickets = tickets.filter((ticket) => {
    return statusFilter === 'all' || ticket.status === statusFilter;
  });

  const statusCounts = {
    open: tickets.filter((t) => t.status === 'open').length,
    scheduled: tickets.filter((t) => t.status === 'scheduled').length,
    in_progress: tickets.filter((t) => t.status === 'in_progress').length,
    completed: tickets.filter((t) => t.status === 'completed').length,
  };

  const getStatusColor = (status: string) => {
    const colors: Record<string, string> = {
      open: 'bg-red-500',
      scheduled: 'bg-blue-500',
      in_progress: 'bg-yellow-500',
      completed: 'bg-green-500',
    };
    return colors[status] || 'bg-gray-500';
  };

  const getPriorityIcon = (priority: string) => {
    const sizes: Record<string, string> = {
      urgent: 'w-6 h-6',
      high: 'w-5 h-5',
      normal: 'w-4 h-4',
      low: 'w-3 h-3',
    };
    return sizes[priority] || 'w-4 h-4';
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-gray-900 dark:text-white">
          Interactive Call Map
        </h1>
        <p className="text-gray-600 dark:text-gray-400 mt-1">
          Visual overview of all service calls by location
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div className="card p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Open Calls</p>
              <p className="text-3xl font-bold text-red-600 mt-2">{statusCounts.open}</p>
            </div>
            <div className="w-3 h-3 rounded-full bg-red-500"></div>
          </div>
        </div>

        <div className="card p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Scheduled</p>
              <p className="text-3xl font-bold text-blue-600 mt-2">{statusCounts.scheduled}</p>
            </div>
            <div className="w-3 h-3 rounded-full bg-blue-500"></div>
          </div>
        </div>

        <div className="card p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">In Progress</p>
              <p className="text-3xl font-bold text-yellow-600 mt-2">
                {statusCounts.in_progress}
              </p>
            </div>
            <div className="w-3 h-3 rounded-full bg-yellow-500"></div>
          </div>
        </div>

        <div className="card p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Completed</p>
              <p className="text-3xl font-bold text-green-600 mt-2">{statusCounts.completed}</p>
            </div>
            <div className="w-3 h-3 rounded-full bg-green-500"></div>
          </div>
        </div>
      </div>

      <div className="card p-6">
        <div className="flex items-center space-x-4 mb-4">
          <Filter className="w-5 h-5 text-gray-600 dark:text-gray-400" />
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="input md:w-64"
          >
            <option value="all">All Statuses</option>
            <option value="open">Open</option>
            <option value="scheduled">Scheduled</option>
            <option value="in_progress">In Progress</option>
            <option value="completed">Completed</option>
          </select>
        </div>

        <div className="bg-gradient-to-br from-blue-50 to-green-50 dark:from-gray-800 dark:to-gray-900 rounded-lg aspect-video relative overflow-hidden border-2 border-gray-300 dark:border-gray-700">
          <svg className="w-full h-full" viewBox="0 0 1000 600" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <pattern id="map-grid" width="50" height="50" patternUnits="userSpaceOnUse">
                <path d="M 50 0 L 0 0 0 50" fill="none" stroke="#cbd5e1" strokeWidth="0.5" opacity="0.3"/>
              </pattern>
            </defs>

            <rect width="1000" height="600" fill="url(#map-grid)"/>

            <path d="M100,200 Q200,150 400,220 T700,250 L850,300"
                  stroke="#94a3b8" strokeWidth="45" fill="none" strokeLinecap="round" opacity="0.3"/>
            <path d="M150,450 Q350,420 550,460 T850,480"
                  stroke="#94a3b8" strokeWidth="45" fill="none" strokeLinecap="round" opacity="0.3"/>
            <path d="M200,50 L200,580"
                  stroke="#94a3b8" strokeWidth="40" fill="none" strokeLinecap="round" opacity="0.3"/>
            <path d="M550,80 L550,550"
                  stroke="#94a3b8" strokeWidth="40" fill="none" strokeLinecap="round" opacity="0.3"/>
            <path d="M800,100 L800,520"
                  stroke="#94a3b8" strokeWidth="35" fill="none" strokeLinecap="round" opacity="0.3"/>

            <rect x="100" y="280" width="70" height="90" fill="#60a5fa" opacity="0.6"/>
            <rect x="250" y="350" width="80" height="70" fill="#60a5fa" opacity="0.6"/>
            <rect x="400" y="200" width="60" height="100" fill="#60a5fa" opacity="0.6"/>
            <rect x="520" y="380" width="90" height="80" fill="#60a5fa" opacity="0.6"/>
            <rect x="680" y="220" width="75" height="95" fill="#60a5fa" opacity="0.6"/>
            <rect x="820" y="420" width="65" height="80" fill="#60a5fa" opacity="0.6"/>
            <rect x="450" y="480" width="100" height="70" fill="#60a5fa" opacity="0.6"/>
            <rect x="720" y="80" width="60" height="70" fill="#60a5fa" opacity="0.6"/>

            <circle cx="300" cy="180" r="45" fill="#22c55e" opacity="0.4"/>
            <circle cx="700" cy="380" r="55" fill="#22c55e" opacity="0.4"/>
            <circle cx="480" cy="320" r="40" fill="#22c55e" opacity="0.4"/>

            {filteredTickets.slice(0, 12).map((ticket, index) => {
              const positions = [
                { x: 280, y: 420, status: 'open' },
                { x: 480, y: 180, status: 'scheduled' },
                { x: 680, y: 320, status: 'in_progress' },
                { x: 820, y: 240, status: 'completed' },
                { x: 380, y: 480, status: 'open' },
                { x: 580, y: 380, status: 'scheduled' },
                { x: 220, y: 280, status: 'in_progress' },
                { x: 750, y: 160, status: 'scheduled' },
                { x: 420, y: 360, status: 'open' },
                { x: 620, y: 480, status: 'completed' },
                { x: 860, y: 380, status: 'in_progress' },
                { x: 320, y: 240, status: 'scheduled' },
              ];

              const pos = positions[index] || positions[0];
              const statusColors: Record<string, string> = {
                open: '#ef4444',
                scheduled: '#3b82f6',
                in_progress: '#eab308',
                completed: '#22c55e',
              };

              const prioritySizes: Record<string, number> = {
                urgent: 28,
                high: 24,
                normal: 20,
                low: 16,
              };

              const pinSize = prioritySizes[ticket.priority] || 20;
              const color = statusColors[ticket.status] || '#6b7280';

              return (
                <g key={ticket.id}>
                  <circle
                    cx={pos.x}
                    cy={pos.y}
                    r={pinSize + 8}
                    fill={color}
                    opacity="0.2"
                  >
                    <animate
                      attributeName="r"
                      from={pinSize + 8}
                      to={pinSize + 18}
                      dur="2s"
                      repeatCount="indefinite"
                    />
                    <animate
                      attributeName="opacity"
                      from="0.2"
                      to="0"
                      dur="2s"
                      repeatCount="indefinite"
                    />
                  </circle>
                  <circle cx={pos.x} cy={pos.y} r={pinSize} fill={color}/>
                  <circle cx={pos.x} cy={pos.y} r={pinSize * 0.5} fill="white"/>
                  <text
                    x={pos.x}
                    y={pos.y + pinSize + 16}
                    fontSize="11"
                    fontWeight="600"
                    fill="#1f2937"
                    textAnchor="middle"
                    className="dark:fill-white"
                  >
                    {ticket.ticket_number}
                  </text>
                </g>
              );
            })}

            <g opacity="0.6">
              <circle cx="150" cy="120" r="8" fill="#dc2626"/>
              <text x="165" y="125" fontSize="12" fontWeight="600" fill="#1f2937" className="dark:fill-white">Dispatch Center</text>
            </g>
          </svg>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="card p-6">
          <h2 className="text-xl font-bold text-gray-900 dark:text-white mb-4">
            Active Service Calls
          </h2>
          <div className="space-y-3 max-h-96 overflow-y-auto">
            {filteredTickets.length === 0 ? (
              <p className="text-center text-gray-600 dark:text-gray-400 py-8">
                No calls found
              </p>
            ) : (
              filteredTickets.map((ticket) => (
                <div
                  key={ticket.id}
                  className="flex items-start space-x-3 p-3 bg-gray-50 dark:bg-gray-700/50 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
                >
                  <div className="flex-shrink-0 mt-1">
                    <div className={`${getStatusColor(ticket.status)} rounded-full p-2`}>
                      <MapPin className={`text-white ${getPriorityIcon(ticket.priority)}`} />
                    </div>
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center space-x-2">
                      <span className="font-medium text-gray-900 dark:text-white">
                        {ticket.ticket_number}
                      </span>
                      <span className="badge badge-gray capitalize">{ticket.status.replace('_', ' ')}</span>
                    </div>
                    <p className="text-sm text-gray-700 dark:text-gray-300 mt-1">
                      {ticket.title}
                    </p>
                    <div className="mt-2 space-y-1">
                      <p className="text-xs text-gray-600 dark:text-gray-400">
                        <span className="font-medium">Customer:</span> {ticket.customers?.name || 'N/A'}
                      </p>
                      {ticket.customers?.address && (
                        <p className="text-xs text-gray-600 dark:text-gray-400">
                          <span className="font-medium">Address:</span> {ticket.customers.address},{' '}
                          {ticket.customers.city}, {ticket.customers.state}
                        </p>
                      )}
                      {ticket.profiles && (
                        <p className="text-xs text-gray-600 dark:text-gray-400">
                          <span className="font-medium">Tech:</span> {ticket.profiles.full_name}
                        </p>
                      )}
                    </div>
                  </div>
                  <button className="btn btn-outline p-2">
                    <Navigation className="w-4 h-4" />
                  </button>
                </div>
              ))
            )}
          </div>
        </div>

        <div className="card p-6">
          <h2 className="text-xl font-bold text-gray-900 dark:text-white mb-4">
            Map Legend
          </h2>
          <div className="space-y-4">
            <div>
              <h3 className="font-medium text-gray-900 dark:text-white mb-2">Status Colors</h3>
              <div className="space-y-2">
                <div className="flex items-center space-x-2">
                  <div className="w-4 h-4 rounded-full bg-red-500"></div>
                  <span className="text-sm text-gray-700 dark:text-gray-300">
                    Open - Requires immediate attention
                  </span>
                </div>
                <div className="flex items-center space-x-2">
                  <div className="w-4 h-4 rounded-full bg-blue-500"></div>
                  <span className="text-sm text-gray-700 dark:text-gray-300">
                    Scheduled - Appointment set
                  </span>
                </div>
                <div className="flex items-center space-x-2">
                  <div className="w-4 h-4 rounded-full bg-yellow-500"></div>
                  <span className="text-sm text-gray-700 dark:text-gray-300">
                    In Progress - Tech on site
                  </span>
                </div>
                <div className="flex items-center space-x-2">
                  <div className="w-4 h-4 rounded-full bg-green-500"></div>
                  <span className="text-sm text-gray-700 dark:text-gray-300">
                    Completed - Job finished
                  </span>
                </div>
              </div>
            </div>

            <div>
              <h3 className="font-medium text-gray-900 dark:text-white mb-2">Pin Sizes</h3>
              <div className="space-y-2">
                <div className="flex items-center space-x-2">
                  <MapPin className="w-6 h-6 text-gray-600" />
                  <span className="text-sm text-gray-700 dark:text-gray-300">
                    Urgent Priority
                  </span>
                </div>
                <div className="flex items-center space-x-2">
                  <MapPin className="w-5 h-5 text-gray-600" />
                  <span className="text-sm text-gray-700 dark:text-gray-300">
                    High Priority
                  </span>
                </div>
                <div className="flex items-center space-x-2">
                  <MapPin className="w-4 h-4 text-gray-600" />
                  <span className="text-sm text-gray-700 dark:text-gray-300">
                    Normal Priority
                  </span>
                </div>
                <div className="flex items-center space-x-2">
                  <MapPin className="w-3 h-3 text-gray-600" />
                  <span className="text-sm text-gray-700 dark:text-gray-300">
                    Low Priority
                  </span>
                </div>
              </div>
            </div>
          </div>

          <div className="mt-6 p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg">
            <p className="text-sm text-blue-700 dark:text-blue-300">
              Click on any pin on the map to view detailed information about the service call
              and get directions.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

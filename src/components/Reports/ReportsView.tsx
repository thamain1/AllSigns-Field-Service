import { useEffect, useState } from 'react';
import {
  BarChart3,
  Download,
  Calendar,
  TrendingUp,
  Clock,
  DollarSign,
  Users,
  Wrench,
} from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface ReportMetrics {
  totalTickets: number;
  completedTickets: number;
  avgCompletionTime: number;
  totalRevenue: number;
  topTechnician: string;
  topTechnicianJobs: number;
  mostUsedPart: string;
  mostUsedPartCount: number;
}

export function ReportsView() {
  const [metrics, setMetrics] = useState<ReportMetrics>({
    totalTickets: 0,
    completedTickets: 0,
    avgCompletionTime: 0,
    totalRevenue: 0,
    topTechnician: 'N/A',
    topTechnicianJobs: 0,
    mostUsedPart: 'N/A',
    mostUsedPartCount: 0,
  });
  const [loading, setLoading] = useState(true);
  const [dateRange, setDateRange] = useState<'week' | 'month' | 'quarter' | 'year'>('month');

  useEffect(() => {
    loadMetrics();
  }, [dateRange]);

  const getDateRange = () => {
    const now = new Date();
    const ranges = {
      week: new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000),
      month: new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000),
      quarter: new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000),
      year: new Date(now.getTime() - 365 * 24 * 60 * 60 * 1000),
    };
    return ranges[dateRange];
  };

  const loadMetrics = async () => {
    try {
      const startDate = getDateRange();

      const { data: ticketsData } = await supabase
        .from('tickets')
        .select('*')
        .gte('created_at', startDate.toISOString());

      const completedTickets = ticketsData?.filter((t) => t.status === 'completed') || [];

      const avgTime =
        completedTickets.length > 0
          ? completedTickets.reduce((sum, t) => {
              if (t.created_at && t.completed_date) {
                const created = new Date(t.created_at).getTime();
                const completed = new Date(t.completed_date).getTime();
                return sum + (completed - created);
              }
              return sum;
            }, 0) / completedTickets.length
          : 0;

      const { data: partsUsage } = await supabase
        .from('parts_usage')
        .select('part_id, parts(name), quantity_used')
        .gte('created_at', startDate.toISOString());

      const partCounts: Record<string, { name: string; count: number }> = {};
      partsUsage?.forEach((usage: any) => {
        const partId = usage.part_id;
        const partName = usage.parts?.name || 'Unknown';
        if (!partCounts[partId]) {
          partCounts[partId] = { name: partName, count: 0 };
        }
        partCounts[partId].count += usage.quantity_used;
      });

      const topPart = Object.values(partCounts).sort((a, b) => b.count - a.count)[0];

      const { data: technicianStats } = await supabase
        .from('tickets')
        .select('assigned_to, profiles!tickets_assigned_to_fkey(full_name)')
        .gte('created_at', startDate.toISOString())
        .not('assigned_to', 'is', null);

      const techCounts: Record<string, { name: string; count: number }> = {};
      technicianStats?.forEach((ticket: any) => {
        const techId = ticket.assigned_to;
        const techName = ticket.profiles?.full_name || 'Unknown';
        if (!techCounts[techId]) {
          techCounts[techId] = { name: techName, count: 0 };
        }
        techCounts[techId].count += 1;
      });

      const topTech = Object.values(techCounts).sort((a, b) => b.count - a.count)[0];

      setMetrics({
        totalTickets: ticketsData?.length || 0,
        completedTickets: completedTickets.length,
        avgCompletionTime: avgTime / (1000 * 60 * 60),
        totalRevenue: completedTickets.length * 250,
        topTechnician: topTech?.name || 'N/A',
        topTechnicianJobs: topTech?.count || 0,
        mostUsedPart: topPart?.name || 'N/A',
        mostUsedPartCount: topPart?.count || 0,
      });
    } catch (error) {
      console.error('Error loading metrics:', error);
    } finally {
      setLoading(false);
    }
  };

  const statCards = [
    {
      title: 'Total Tickets',
      value: metrics.totalTickets,
      icon: Wrench,
      color: 'text-blue-600',
      bgColor: 'bg-blue-100 dark:bg-blue-900/20',
      suffix: '',
    },
    {
      title: 'Completed',
      value: metrics.completedTickets,
      icon: TrendingUp,
      color: 'text-green-600',
      bgColor: 'bg-green-100 dark:bg-green-900/20',
      suffix: '',
    },
    {
      title: 'Avg Completion',
      value: metrics.avgCompletionTime.toFixed(1),
      icon: Clock,
      color: 'text-yellow-600',
      bgColor: 'bg-yellow-100 dark:bg-yellow-900/20',
      suffix: 'hrs',
    },
    {
      title: 'Est. Revenue',
      value: `$${metrics.totalRevenue.toLocaleString()}`,
      icon: DollarSign,
      color: 'text-red-600',
      bgColor: 'bg-red-100 dark:bg-red-900/20',
      suffix: '',
    },
  ];

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 dark:text-white">
            Reports & Analytics
          </h1>
          <p className="text-gray-600 dark:text-gray-400 mt-1">
            Performance metrics and business insights
          </p>
        </div>
        <button className="btn btn-primary flex items-center space-x-2">
          <Download className="w-5 h-5" />
          <span>Export Report</span>
        </button>
      </div>

      <div className="card p-6">
        <div className="flex items-center space-x-4">
          <Calendar className="w-5 h-5 text-gray-600 dark:text-gray-400" />
          <span className="text-sm text-gray-700 dark:text-gray-300">Date Range:</span>
          <div className="flex space-x-2">
            {(['week', 'month', 'quarter', 'year'] as const).map((range) => (
              <button
                key={range}
                onClick={() => setDateRange(range)}
                className={`btn ${
                  dateRange === range ? 'btn-primary' : 'btn-outline'
                } capitalize`}
              >
                {range}
              </button>
            ))}
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {statCards.map((card) => {
          const Icon = card.icon;
          return (
            <div key={card.title} className="card p-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-gray-600 dark:text-gray-400">{card.title}</p>
                  <p className="text-3xl font-bold text-gray-900 dark:text-white mt-2">
                    {card.value}
                    {card.suffix && (
                      <span className="text-lg text-gray-600 dark:text-gray-400 ml-1">
                        {card.suffix}
                      </span>
                    )}
                  </p>
                </div>
                <div className={`${card.bgColor} ${card.color} p-3 rounded-lg`}>
                  <Icon className="w-6 h-6" />
                </div>
              </div>
            </div>
          );
        })}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="card p-6">
          <h2 className="text-xl font-bold text-gray-900 dark:text-white mb-4">
            Performance Overview
          </h2>
          <div className="bg-gray-200 dark:bg-gray-700 rounded-lg aspect-video flex items-center justify-center">
            <div className="text-center">
              <BarChart3 className="w-16 h-16 text-gray-400 mx-auto mb-2" />
              <p className="text-gray-600 dark:text-gray-400">Chart Visualization</p>
              <p className="text-sm text-gray-500 dark:text-gray-500 mt-1">
                Integration with Chart.js or Recharts
              </p>
            </div>
          </div>
        </div>

        <div className="card p-6">
          <h2 className="text-xl font-bold text-gray-900 dark:text-white mb-4">
            Top Performers
          </h2>
          <div className="space-y-4">
            <div className="p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg">
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  <div className="bg-blue-600 p-2 rounded-lg">
                    <Users className="w-5 h-5 text-white" />
                  </div>
                  <div>
                    <p className="text-sm text-gray-600 dark:text-gray-400">Top Technician</p>
                    <p className="font-bold text-gray-900 dark:text-white">
                      {metrics.topTechnician}
                    </p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-2xl font-bold text-blue-600">
                    {metrics.topTechnicianJobs}
                  </p>
                  <p className="text-xs text-gray-600 dark:text-gray-400">jobs</p>
                </div>
              </div>
            </div>

            <div className="p-4 bg-green-50 dark:bg-green-900/20 rounded-lg">
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  <div className="bg-green-600 p-2 rounded-lg">
                    <Wrench className="w-5 h-5 text-white" />
                  </div>
                  <div>
                    <p className="text-sm text-gray-600 dark:text-gray-400">Most Used Part</p>
                    <p className="font-bold text-gray-900 dark:text-white">
                      {metrics.mostUsedPart}
                    </p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-2xl font-bold text-green-600">
                    {metrics.mostUsedPartCount}
                  </p>
                  <p className="text-xs text-gray-600 dark:text-gray-400">used</p>
                </div>
              </div>
            </div>

            <div className="p-4 bg-yellow-50 dark:bg-yellow-900/20 rounded-lg">
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  <div className="bg-yellow-600 p-2 rounded-lg">
                    <TrendingUp className="w-5 h-5 text-white" />
                  </div>
                  <div>
                    <p className="text-sm text-gray-600 dark:text-gray-400">Completion Rate</p>
                    <p className="font-bold text-gray-900 dark:text-white">
                      {metrics.totalTickets > 0
                        ? ((metrics.completedTickets / metrics.totalTickets) * 100).toFixed(1)
                        : 0}
                      %
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="card p-6">
        <h2 className="text-xl font-bold text-gray-900 dark:text-white mb-4">
          Export Options
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <button className="btn btn-outline flex items-center justify-center space-x-2">
            <Download className="w-5 h-5" />
            <span>Export to Excel</span>
          </button>
          <button className="btn btn-outline flex items-center justify-center space-x-2">
            <Download className="w-5 h-5" />
            <span>Export to PDF</span>
          </button>
          <button className="btn btn-outline flex items-center justify-center space-x-2">
            <Download className="w-5 h-5" />
            <span>Export to CSV</span>
          </button>
        </div>
      </div>
    </div>
  );
}

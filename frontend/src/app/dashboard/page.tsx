'use client';

import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Users, Globe, Activity, TrendingUp, ArrowLeft, LogOut } from 'lucide-react';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8888';
const DASHBOARD_TOKEN_KEY = 'dashboard_admin_token';

interface CountryDetail {
  name: string;
  code: string;
  count: number;
}

interface FirebaseUser {
  uid: string;
  email: string;
  provider: string;
  country?: string;
  country_code?: string;
  created?: number;
}

interface FirebaseUsersStats {
  total: number;
  anonymous: number;
  registered: number;
  by_provider: Record<string, number>;
  users: FirebaseUser[];
}

interface Stats {
  total_events: number;
  unique_users: number;
  unique_trial_users: number;
  trial_devices_count: number;
  events_last_5min: number;
  active_users_5min: number;
  firebase_users?: FirebaseUsersStats;
  countries: Record<string, number>;
  countries_detail: CountryDetail[];
  countries_trial?: Record<string, number>;
  countries_trial_detail?: CountryDetail[];
  by_event_type: Record<string, number>;
  by_day: Record<string, number>;
  period_days: number;
}

const PROVIDER_LABELS: Record<string, string> = {
  'google.com': 'Google',
  'password': 'Email',
  'anonymous': 'Anonyme',
};

function getFlagEmoji(code: string): string {
  if (!code || code.length !== 2) return '🌍';
  return code
    .toUpperCase()
    .split('')
    .map((c) => String.fromCodePoint(0x1f1e6 - 65 + c.charCodeAt(0)))
    .join('');
}

function getDashboardToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem(DASHBOARD_TOKEN_KEY);
}

function setDashboardToken(token: string) {
  if (typeof window !== 'undefined') localStorage.setItem(DASHBOARD_TOKEN_KEY, token);
}

function clearDashboardToken() {
  if (typeof window !== 'undefined') localStorage.removeItem(DASHBOARD_TOKEN_KEY);
}

async function loginDashboard(email: string, password: string): Promise<string> {
  const res = await fetch(`${API_URL}/api/v1/admin/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail || 'Identifiants invalides');
  }
  const data = await res.json();
  return data.token;
}

async function fetchStats(token: string, days: number): Promise<Stats | null> {
  const res = await fetch(`${API_URL}/api/v1/analytics/stats?days=${days}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) return null;
  return res.json();
}

export default function DashboardPage() {
  const router = useRouter();
  const [token, setToken] = useState<string | null>(null);
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(true);
  const [days, setDays] = useState(30);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);

  // Login form (auth dashboard indépendante)
  const [loginEmail, setLoginEmail] = useState('');
  const [loginPassword, setLoginPassword] = useState('');
  const [loginError, setLoginError] = useState('');
  const [loginLoading, setLoginLoading] = useState(false);

  useEffect(() => {
    setToken(getDashboardToken());
  }, []);

  useEffect(() => {
    if (!token) {
      setLoading(false);
      return;
    }
    setLoading(true);
    fetchStats(token, days)
      .then((data) => {
        setStats(data);
        setLastUpdated(new Date());
      })
      .catch(() => setStats(null))
      .finally(() => setLoading(false));
  }, [token, days]);
  const handleManualRefresh = async () => {
    if (!token) return;
    setLoading(true);
    try {
      const data = await fetchStats(token, days);
      setStats(data);
      setLastUpdated(new Date());
    } finally {
      setLoading(false);
    }
  };

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoginError('');
    setLoginLoading(true);
    try {
      const t = await loginDashboard(loginEmail, loginPassword);
      setDashboardToken(t);
      setToken(t);
    } catch (err) {
      setLoginError(err instanceof Error ? err.message : 'Erreur de connexion');
    } finally {
      setLoginLoading(false);
    }
  };

  const handleLogout = () => {
    clearDashboardToken();
    setToken(null);
    setStats(null);
  };

  // Écran login (auth indépendante de l'app)
  if (!token) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center bg-gray-900 p-6">
        <h1 className="text-xl font-bold text-white mb-6">Dashboard MediScan</h1>
        <form onSubmit={handleLogin} className="w-full max-w-sm space-y-4">
          <input
            type="email"
            placeholder="Email"
            value={loginEmail}
            onChange={(e) => setLoginEmail(e.target.value)}
            required
            className="w-full px-4 py-3 rounded-lg bg-gray-800 text-white placeholder-gray-500 border border-gray-700 focus:border-primary focus:outline-none"
          />
          <input
            type="password"
            placeholder="Mot de passe"
            value={loginPassword}
            onChange={(e) => setLoginPassword(e.target.value)}
            required
            className="w-full px-4 py-3 rounded-lg bg-gray-800 text-white placeholder-gray-500 border border-gray-700 focus:border-primary focus:outline-none"
          />
          {loginError && <p className="text-red-400 text-sm">{loginError}</p>}
          <button
            type="submit"
            disabled={loginLoading}
            className="w-full py-3 rounded-lg bg-primary text-white font-medium disabled:opacity-50"
          >
            {loginLoading ? 'Connexion...' : 'Connexion'}
          </button>
        </form>
      </div>
    );
  }

  const maxByDay = stats ? Math.max(...Object.values(stats.by_day), 1) : 1;
  const maxByCountry = stats ? Math.max(...Object.values(stats.countries), 1) : 1;

  return (
    <div className="min-h-screen bg-gray-900 text-white p-4 sm:p-6 lg:p-8">
      <div className="max-w-5xl mx-auto">
        <div className="flex items-center justify-between mb-6">
          <button
            onClick={() => router.push('/')}
            className="flex items-center gap-2 text-gray-400 hover:text-white"
          >
            <ArrowLeft className="w-5 h-5" />
            Retour à l&apos;app
          </button>
          <button
            onClick={handleLogout}
            className="flex items-center gap-2 text-gray-400 hover:text-red-400"
          >
            <LogOut className="w-5 h-5" />
            Déconnexion
          </button>
        </div>

        <h1 className="text-2xl sm:text-3xl font-bold mb-2">Dashboard MediScan</h1>
        <p className="text-gray-400 text-sm mb-2">Analytique propriétaire</p>
        {lastUpdated && (
          <p className="text-xs text-gray-500 mb-6">
            Dernière mise à jour&nbsp;:
            {lastUpdated.toLocaleTimeString('fr-FR')}
          </p>
        )}

        <div className="flex flex-wrap gap-2 mb-8 items-center">
          {[7, 30, 90].map((d) => (
            <button
              key={d}
              onClick={() => setDays(d)}
              className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                days === d ? 'bg-primary text-white' : 'bg-gray-800 text-gray-400 hover:bg-gray-700'
              }`}
            >
              {d} jours
            </button>
          ))}
          <button
            onClick={handleManualRefresh}
            disabled={loading || !token}
            className="px-4 py-2 rounded-lg text-sm font-medium bg-gray-800 text-gray-200 hover:bg-gray-700 disabled:opacity-50"
          >
            {loading ? 'Chargement...' : 'Rafraîchir'}
          </button>
        </div>

        {loading ? (
          <div className="flex justify-center py-12">
            <div className="w-10 h-10 border-3 border-primary/30 border-t-primary rounded-full animate-spin" />
          </div>
        ) : stats ? (
          <div className="space-y-8">
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4">
              <StatCard
                icon={<Activity className="w-6 h-6" />}
                label="Événements"
                value={stats.total_events}
              />
              <StatCard
                icon={<Activity className="w-6 h-6" />}
                label="Événements (5 dernières min)"
                value={stats.events_last_5min}
              />
              <StatCard
                icon={<Users className="w-6 h-6" />}
                label="Firebase total"
                value={stats.firebase_users?.total ?? 0}
              />
              <StatCard
                icon={<Users className="w-6 h-6" />}
                label="Inscrits (email/Google)"
                value={stats.firebase_users?.registered ?? 0}
              />
              <StatCard
                icon={<Users className="w-6 h-6" />}
                label="Anonymes (essai)"
                value={stats.firebase_users?.anonymous ?? 0}
              />
              <StatCard
                icon={<Users className="w-6 h-6" />}
                label="Utilisateurs actifs (5 min)"
                value={stats.active_users_5min}
              />
              <StatCard
                icon={<Globe className="w-6 h-6" />}
                label="Pays"
                value={Object.keys(stats.countries).length}
              />
              <StatCard
                icon={<TrendingUp className="w-6 h-6" />}
                label="Période"
                value={`${stats.period_days} jours`}
              />
            </div>

            {stats.firebase_users && stats.firebase_users.users.length > 0 && (
              <div className="bg-gray-800 rounded-xl p-6">
                <h2 className="text-lg font-bold mb-4">Utilisateurs Firebase (console)</h2>
                <p className="text-gray-400 text-sm mb-4">
                  Pays détecté depuis l&apos;IP lors de l&apos;utilisation de l&apos;app
                </p>
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="text-left text-gray-400 border-b border-gray-700">
                        <th className="py-2 pr-4">Email / Identifiant</th>
                        <th className="py-2 pr-4">Fournisseur</th>
                        <th className="py-2 pr-4">Pays</th>
                        <th className="py-2">Créé le</th>
                      </tr>
                    </thead>
                    <tbody>
                      {stats.firebase_users.users.map((u) => (
                        <tr key={u.uid} className="border-b border-gray-700/50">
                          <td className="py-2 pr-4 text-gray-300">{u.email}</td>
                          <td className="py-2 pr-4">{PROVIDER_LABELS[u.provider] || u.provider}</td>
                          <td className="py-2 pr-4">
                            <span className="mr-1">{getFlagEmoji(u.country_code || '')}</span>
                            {u.country || '-'}
                          </td>
                          <td className="py-2 text-gray-500">
                            {u.created
                              ? new Date(u.created * 1000).toLocaleDateString('fr-FR')
                              : '-'}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            )}

            <div className="bg-gray-800 rounded-xl p-6">
              <h2 className="text-lg font-bold mb-4">Par pays (avec drapeau)</h2>
              <div className="space-y-3">
                {(stats.countries_detail || Object.entries(stats.countries).map(([name, count]) => ({ name, code: '', count })))
                  .slice(0, 15)
                  .map((c) => (
                    <div key={c.name} className="flex items-center gap-3">
                      <span className="text-xl" title={c.name}>{getFlagEmoji(c.code || '')}</span>
                      <span className="w-32 text-sm text-gray-300">{c.name}</span>
                      <div className="flex-1 h-6 bg-gray-700 rounded overflow-hidden">
                        <div
                          className="h-full bg-primary rounded"
                          style={{ width: `${((c.count || 0) / maxByCountry) * 100}%` }}
                        />
                      </div>
                      <span className="text-sm font-medium w-12">{c.count}</span>
                    </div>
                  ))}
              </div>
            </div>

            {(stats.countries_trial_detail?.length ?? 0) > 0 && (
              <div className="bg-gray-800 rounded-xl p-6">
                <h2 className="text-lg font-bold mb-4">Pays des essais (trial)</h2>
                <div className="space-y-3">
                  {(stats.countries_trial_detail || [])
                    .slice(0, 10)
                    .map((c) => (
                      <div key={c.name} className="flex items-center gap-3">
                        <span className="text-xl">{getFlagEmoji(c.code || '')}</span>
                        <span className="w-32 text-sm text-gray-300">{c.name}</span>
                        <span className="text-sm font-medium">{c.count} essai(s)</span>
                      </div>
                    ))}
                </div>
              </div>
            )}

            <div className="bg-gray-800 rounded-xl p-6">
              <h2 className="text-lg font-bold mb-4">Par type d&apos;événement</h2>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                {Object.entries(stats.by_event_type).map(([type, count]) => (
                  <div key={type} className="flex justify-between items-center p-3 bg-gray-700/50 rounded-lg">
                    <span className="text-sm">{type}</span>
                    <span className="font-bold">{count}</span>
                  </div>
                ))}
              </div>
            </div>

            <div className="bg-gray-800 rounded-xl p-6">
              <h2 className="text-lg font-bold mb-4">Évolution quotidienne</h2>
              <div className="flex gap-1 h-32 items-end">
                {Object.entries(stats.by_day).map(([day, count]) => (
                  <div
                    key={day}
                    className="flex-1 min-w-[4px] bg-primary rounded-t transition-all"
                    style={{ height: `${(count / maxByDay) * 100}%` }}
                    title={`${day}: ${count}`}
                  />
                ))}
              </div>
              <div className="flex justify-between mt-2 text-xs text-gray-500">
                <span>{Object.keys(stats.by_day)[0]}</span>
                <span>{Object.keys(stats.by_day).pop()}</span>
              </div>
            </div>
          </div>
        ) : (
          <p className="text-gray-400 text-center py-12">Aucune donnée disponible</p>
        )}
      </div>
    </div>
  );
}

function StatCard({
  icon,
  label,
  value,
}: {
  icon: React.ReactNode;
  label: string;
  value: string | number;
}) {
  return (
    <div className="bg-gray-800 rounded-xl p-6 flex flex-col gap-2">
      <div className="text-primary">{icon}</div>
      <p className="text-2xl font-bold">{value}</p>
      <p className="text-sm text-gray-400">{label}</p>
    </div>
  );
}

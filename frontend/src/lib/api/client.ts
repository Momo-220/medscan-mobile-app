import axios, { AxiosInstance, AxiosRequestConfig } from 'axios';
import { errorTranslator } from '@/lib/errors/errorTranslator';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8888';

const DEFAULT_TIMEOUT = 45000; // 45s (cold start Firebase + premier chargement)
const SLOW_ENDPOINT_TIMEOUT = 25000; // 25s pour history/reminders/credits

class APIClient {
  private client: AxiosInstance;

  constructor() {
    this.client = axios.create({
      baseURL: `${API_URL}/api/v1`,
      timeout: DEFAULT_TIMEOUT,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    // Request interceptor for auth token
    this.client.interceptors.request.use(
      (config) => {
        const token = this.getStoredToken();
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
      },
      (error) => Promise.reject(error)
    );

    // Response interceptor for error handling
    this.client.interceptors.response.use(
      (response) => response,
      async (error) => {
        const status = error.response?.status || error.status;
        const isTimeoutOrNetwork =
          error.code === 'ECONNABORTED' ||
          error.code === 'ERR_NETWORK' ||
          error.message?.includes('timeout') ||
          error.message?.includes('Network Error') ||
          error.message?.includes('Failed to fetch');
        const backendWaking = typeof window !== 'undefined' && !!(window as any).__MEDISCAN_BACKEND_WAKING__;

        // Pendant le cold start, ne pas afficher l'alerte timeout/réseau : le skeleton fait office de feedback
        if (backendWaking && isTimeoutOrNetwork) {
          return Promise.reject(error);
        }

        // Cas spécial 401: essayer de rafraîchir le token en silence, sans afficher le gros toast
        if (status === 401) {
          if (typeof window !== 'undefined') {
            const event = new CustomEvent('refreshFirebaseToken');
            window.dispatchEvent(event);
            // Attendre un peu pour que le token soit rafraîchi
            await new Promise((resolve) => setTimeout(resolve, 1000));
            // Réessayer la requête avec le nouveau token si disponible
            const newToken = this.getStoredToken();
            if (newToken && error.config && !error.config.__retried) {
              (error.config as any).__retried = true;
              error.config.headers = error.config.headers || {};
              (error.config.headers as any).Authorization = `Bearer ${newToken}`;
              return this.client.request(error.config);
            }
          }
          // Si le rafraîchissement échoue, supprimer le token mais ne pas afficher de toast
          this.clearStoredToken();
          return Promise.reject(error);
        }

        // Afficher l'erreur seulement si l'utilisateur est connecté (token présent)
        if (typeof window !== 'undefined' && this.getStoredToken()) {
          try {
            const errorInfo = errorTranslator.translate(error);
            const event = new CustomEvent('showError', { detail: errorInfo });
            window.dispatchEvent(event);
          } catch (e) {
            console.error('Erreur lors de la traduction:', e);
          }
        }

        if (status === 402 && typeof window !== 'undefined') {
          window.dispatchEvent(new CustomEvent('insufficientCredits'));
        }
        return Promise.reject(error);
      }
    );
  }

  private getStoredToken(): string | null {
    if (typeof window === 'undefined') return null;
    return sessionStorage.getItem('auth_token');
  }

  private clearStoredToken(): void {
    if (typeof window === 'undefined') return;
    sessionStorage.removeItem('auth_token');
  }

  setAuthToken(token: string): void {
    if (typeof window === 'undefined') return;
    sessionStorage.setItem('auth_token', token);
  }

  // Scan (timeout 60s: backend + Gemini peuvent prendre du temps)
  async scanMedication(file: File, language: string = 'fr'): Promise<any> {
    const formData = new FormData();
    formData.append('file', file);

    const response = await this.client.post(`/scan?language=${language}`, formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
      timeout: 60000,
    });

    return response.data;
  }

  async getScan(scanId: string): Promise<any> {
    const response = await this.client.get(`/scan/${scanId}`);
    return response.data;
  }

  // Assistant endpoints
  async chat(message: string, includeHistory: boolean = true): Promise<any> {
    const response = await this.client.post('/assistant/chat', {
      message,
      include_history: includeHistory,
      stream: false,
    });

    return response.data;
  }

  // Streaming chat endpoint
  async chatStream(
    message: string,
    includeHistory: boolean = true,
    onChunk: (chunk: string) => void,
    onComplete: (fullMessage: string) => void,
    onError: (error: Error) => void,
    language: string = 'fr'
  ): Promise<void> {
    const token = this.getStoredToken();
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    };
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    try {
      // Valider le message avant l'envoi
      const trimmedMessage = message.trim();
      if (!trimmedMessage) {
        throw new Error('Le message ne peut pas être vide');
      }
      
      if (trimmedMessage.length > 2000) {
        throw new Error('Le message ne peut pas dépasser 2000 caractères');
      }

      const requestBody = {
        message: trimmedMessage,
        include_history: includeHistory,
        language: language,
      };

      console.log('Sending chat request:', { 
        messageLength: trimmedMessage.length, 
        includeHistory,
        requestBody 
      });

      const response = await fetch(`${API_URL}/api/v1/assistant/chat/stream`, {
        method: 'POST',
        headers,
        body: JSON.stringify(requestBody),
      });

      if (!response.ok) {
        if (response.status === 402) {
          if (typeof window !== 'undefined') window.dispatchEvent(new CustomEvent('insufficientCredits'));
          const error = new Error('INSUFFICIENT_CREDITS');
          (error as any).status = 402;
          throw error;
        }

        // Try to get error details from response
        let errorMessage = `HTTP error! status: ${response.status}`;
        let errorDetails: any = null;
        try {
          const errorData = await response.json();
          errorDetails = errorData;
          // Extraire le message d'erreur détaillé
          if (errorData.detail) {
            if (Array.isArray(errorData.detail)) {
              // Si c'est un tableau d'erreurs de validation Pydantic
              errorMessage = errorData.detail.map((err: any) => 
                `${err.loc?.join('.')}: ${err.msg}`
              ).join(', ');
            } else {
              errorMessage = errorData.detail;
            }
          } else if (errorData.message) {
            errorMessage = errorData.message;
          } else if (errorData.error) {
            errorMessage = errorData.error;
          }
          console.error('Chat stream error details:', errorData);
        } catch (e) {
          // If response is not JSON, use status text
          errorMessage = response.statusText || errorMessage;
          console.error('Failed to parse error response:', e);
        }
        
        // Logger les détails complets de l'erreur pour debugging
        console.error('Chat streaming error:', {
          status: response.status,
          statusText: response.statusText,
          errorMessage,
          errorDetails,
          requestBody,
          url: `${API_URL}/api/v1/assistant/chat/stream`
        });
        
        throw new Error(errorMessage);
      }

      const reader = response.body?.getReader();
      const decoder = new TextDecoder();
      let fullMessage = '';

      if (!reader) {
        throw new Error('No response body');
      }

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        const chunk = decoder.decode(value);
        const lines = chunk.split('\n');

        for (const line of lines) {
          if (line.startsWith('data: ')) {
            try {
              const data = JSON.parse(line.slice(6));
              if (data.chunk) {
                fullMessage += data.chunk;
                onChunk(data.chunk);
              }
              if (data.done) {
                onComplete(fullMessage);
                return;
              }
              if (data.error) {
                // Gérer spécifiquement l'erreur de crédits insuffisants
                if (data.error === 'INSUFFICIENT_CREDITS' || data.status === 402) {
                  if (typeof window !== 'undefined') window.dispatchEvent(new CustomEvent('insufficientCredits'));
                  const error = new Error('INSUFFICIENT_CREDITS');
                  (error as any).status = 402;
                  throw error;
                }
                throw new Error(data.error);
              }
            } catch (e) {
              // Si c'est une erreur de crédits, la propager
              if (e instanceof Error && e.message === 'INSUFFICIENT_CREDITS') {
                throw e;
              }
              // Ignore JSON parse errors for incomplete chunks
            }
          }
        }
      }
    } catch (error) {
      // Améliorer la gestion d'erreur pour afficher le vrai message
      let errorMessage = 'Unknown error';
      if (error instanceof Error) {
        errorMessage = error.message;
      } else if (typeof error === 'object' && error !== null) {
        // Si c'est un objet, essayer d'extraire le message
        if ('message' in error) {
          errorMessage = String(error.message);
        } else if ('detail' in error) {
          errorMessage = String(error.detail);
        } else {
          errorMessage = JSON.stringify(error);
        }
      } else {
        errorMessage = String(error);
      }
      onError(new Error(errorMessage));
    }
  }

  async getChatHistory(limit: number = 100): Promise<any> {
    try {
      const response = await this.client.get('/assistant/history', {
        params: { limit },
        timeout: 10000, // 10 secondes au lieu de 60
      });
      return response.data;
    } catch (error: any) {
      // Si timeout ou erreur, retourner une liste vide au lieu de planter
      if (error.code === 'ECONNABORTED' || error.response?.status === 403) {
        console.warn('Chat history unavailable, starting with empty history');
        return { messages: [], total: 0 };
      }
      throw error;
    }
  }

  // History endpoints (timeout + 1 retry pour robustesse)
  async getHistory(limit: number = 50, page: number = 1): Promise<any> {
    const request = () => this.client.get('/history', {
      params: { limit, page },
      timeout: SLOW_ENDPOINT_TIMEOUT,
    });
    try {
      const response = await request();
      return response.data;
    } catch (err: any) {
      if ((err.code === 'ECONNABORTED' || err.code === 'ERR_NETWORK') && !(err as any).__retried) {
        (err as any).__retried = true;
        await new Promise((r) => setTimeout(r, 1500));
        const response = await request();
        return response.data;
      }
      throw err;
    }
  }

  // Feedback endpoint
  async submitFeedback(data: {
    scan_id?: string;
    rating: number;
    feedback_type: string;
    comment?: string;
  }): Promise<any> {
    const response = await this.client.post('/feedback', data);
    return response.data;
  }

  // Suggestions endpoint
  async getSuggestions(
    category: string, 
    language: string, 
    limit: number = 50,  // Augmenté à 50 par défaut
    medicationName?: string,
    genericName?: string,
    indications?: string,
    activeIngredient?: string
  ): Promise<any> {
    const params: any = { category, language, limit };
    if (medicationName) params.medication_name = medicationName;
    if (genericName) params.generic_name = genericName;
    if (indications) params.indications = indications;
    if (activeIngredient) params.active_ingredient = activeIngredient;
    
    // Timeout court car base de données locale (< 10ms)
    const response = await this.client.get('/suggestions', { 
      params,
      timeout: 5000  // 5 secondes suffisent pour base locale
    });
    return response.data;
  }

  // Reminders endpoints (timeout + 1 retry)
  async getReminders(activeOnly: boolean = true, limit: number = 50): Promise<any> {
    const request = () => this.client.get('/reminders', {
      params: { active_only: activeOnly, limit },
      timeout: SLOW_ENDPOINT_TIMEOUT,
    });
    try {
      const response = await request();
      return response.data;
    } catch (err: any) {
      if ((err.code === 'ECONNABORTED' || err.code === 'ERR_NETWORK') && !(err as any).__retried) {
        (err as any).__retried = true;
        await new Promise((r) => setTimeout(r, 1500));
        const response = await request();
        return response.data;
      }
      throw err;
    }
  }

  async createReminder(data: {
    medication_name: string;
    dosage: string;
    time: string;
    frequency: 'daily' | 'twice' | 'three-times' | 'custom';
    days?: number[];
    notes?: string;
  }): Promise<any> {
    const response = await this.client.post('/reminders', data);
    return response.data;
  }

  async updateReminder(reminderId: string, data: {
    medication_name?: string;
    dosage?: string;
    time?: string;
    frequency?: 'daily' | 'twice' | 'three-times' | 'custom';
    days?: number[];
    notes?: string;
    active?: boolean;
  }): Promise<any> {
    const response = await this.client.put(`/reminders/${reminderId}`, data);
    return response.data;
  }

  async deleteReminder(reminderId: string): Promise<void> {
    await this.client.delete(`/reminders/${reminderId}`);
  }

  async markReminderTaken(reminderId: string, takenAt?: Date, notes?: string): Promise<any> {
    const response = await this.client.post(`/reminders/${reminderId}/take`, {
      taken_at: takenAt || new Date().toISOString(),
      notes,
    });
    return response.data;
  }

  // Analytics endpoints
  async trackEvent(eventType: string, deviceId?: string, metadata?: Record<string, unknown>): Promise<void> {
    try {
      await this.client.post('/analytics/track', {
        event_type: eventType,
        device_id: deviceId,
        metadata: metadata ?? undefined,
      });
    } catch {
      // Silently fail - analytics non-blocking
    }
  }

  async getAnalyticsStats(days: number = 30): Promise<{
    total_events: number;
    unique_users: number;
    countries: Record<string, number>;
    by_event_type: Record<string, number>;
    by_day: Record<string, number>;
    period_days: number;
  }> {
    const response = await this.client.get('/analytics/stats', { params: { days } });
    return response.data;
  }

  // Trial endpoints
  async checkTrial(deviceId: string): Promise<{ can_use_trial: boolean; reason?: string }> {
    const response = await this.client.post('/trial/check', { device_id: deviceId });
    return response.data;
  }

  async registerTrial(deviceId: string): Promise<void> {
    await this.client.post('/trial/register', { device_id: deviceId });
  }

  // Credits endpoints (timeout + 1 retry)
  async getCredits(): Promise<{ credits: number; next_reset_at?: string }> {
    const request = () => this.client.get('/credits', { timeout: SLOW_ENDPOINT_TIMEOUT });
    try {
      const response = await request();
      return response.data;
    } catch (err: any) {
      if ((err.code === 'ECONNABORTED' || err.code === 'ERR_NETWORK') && !(err as any).__retried) {
        (err as any).__retried = true;
        await new Promise((r) => setTimeout(r, 1500));
        const response = await request();
        return response.data;
      }
      throw err;
    }
  }

  async addCredits(amount: number): Promise<{ credits: number; next_reset_at?: string }> {
    const response = await this.client.post('/credits/add', { amount });
    return response.data;
  }

  // Generic request method
  async request<T = any>(config: AxiosRequestConfig): Promise<T> {
    const response = await this.client.request<T>(config);
    return response.data;
  }
}

// Export singleton instance
export const apiClient = new APIClient();


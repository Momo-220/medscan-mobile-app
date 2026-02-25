'use client';

import React, { createContext, useContext, useState, useEffect, useRef, useCallback } from 'react';
import { apiClient } from '@/lib/api/client';
import { getFirebaseAuth } from '@/lib/firebase/config';

interface User {
  uid: string;
  email: string | null;
  displayName: string | null;
  photoURL: string | null;
  emailVerified: boolean;
  isAnonymous: boolean;
}

interface AuthContextType {
  user: User | null;
  loading: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signUp: (email: string, password: string, displayName?: string) => Promise<void>;
  signInWithGoogle: () => Promise<void>;
  signInAnonymously: () => Promise<void>;
  signOut: () => Promise<void>;
  getIdToken: () => Promise<string | null>;
  updateProfile: (updates: { displayName?: string; photoURL?: string }) => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

function mapUser(fbUser: any): User {
  return {
    uid: fbUser.uid,
    email: fbUser.email,
    displayName: fbUser.displayName,
    photoURL: fbUser.photoURL,
    emailVerified: fbUser.emailVerified ?? false,
    isAnonymous: fbUser.isAnonymous ?? false,
  };
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const authRef = useRef<any>(null);
  const authModuleRef = useRef<any>(null);

  // Initialize Firebase Auth dynamically (avoids undici SSR issue)
  useEffect(() => {
    let unsubscribe: (() => void) | null = null;
    let refreshTokenHandler: (() => void) | null = null;

    const init = async () => {
      try {
        const auth = await getFirebaseAuth();
        authRef.current = auth;
        const authModule = await import('firebase/auth');
        authModuleRef.current = authModule;

        const handleAuthState = async (fbUser: any) => {
          if (fbUser) {
            setUser(mapUser(fbUser));
            try {
              // Récupérer le token avec rafraîchissement forcé si nécessaire
              const token = await fbUser.getIdToken(false);
              apiClient.setAuthToken(token);
            } catch (e: any) {
              console.error('Failed to get token:', e);
            }
          } else {
            setUser(null);
            apiClient.setAuthToken('');
          }
          setLoading(false);
        };

        await authModule.setPersistence(auth, authModule.browserLocalPersistence).catch(() => {});
        const redirectResult = await authModule.getRedirectResult(auth).catch(() => null);
        if (redirectResult?.user) {
          await handleAuthState(redirectResult.user);
        }
        unsubscribe = authModule.onAuthStateChanged(auth, handleAuthState);

        // Écouter les événements de rafraîchissement de token depuis l'API client
        refreshTokenHandler = async () => {
          const authInstance = authRef.current;
          if (authInstance?.currentUser) {
            try {
              const token = await authInstance.currentUser.getIdToken(true);
              apiClient.setAuthToken(token);
            } catch (e) {
              console.error('Failed to refresh token:', e);
            }
          }
        };
        if (typeof window !== 'undefined') {
          window.addEventListener('refreshFirebaseToken', refreshTokenHandler);
        }
      } catch (e) {
        console.error('Firebase init error:', e);
        setLoading(false);
      }
    };

    init();
    return () => {
      if (unsubscribe) unsubscribe();
      if (typeof window !== 'undefined' && refreshTokenHandler) {
        window.removeEventListener('refreshFirebaseToken', refreshTokenHandler);
      }
    };
  }, []);

  const signIn = useCallback(async (email: string, password: string) => {
    const auth = authRef.current;
    const mod = authModuleRef.current;
    if (!auth || !mod) throw new Error('Auth not initialized');
    const credential = await mod.signInWithEmailAndPassword(auth, email, password);
    const token = await credential.user.getIdToken();
    apiClient.setAuthToken(token);
  }, []);

  const signUp = useCallback(async (email: string, password: string, displayName?: string) => {
    const auth = authRef.current;
    const mod = authModuleRef.current;
    if (!auth || !mod) throw new Error('Auth not initialized');
    try {
      const credential = await mod.createUserWithEmailAndPassword(auth, email, password);
      if (displayName) {
        await mod.updateProfile(credential.user, { displayName });
      }
      const token = await credential.user.getIdToken();
      apiClient.setAuthToken(token);
    } catch (err: any) {
      // Email déjà inscrit → se connecter à la place (retrouve les anciennes données)
      if (err?.code === 'auth/email-already-in-use') {
        try {
          const cred = await mod.signInWithEmailAndPassword(auth, email, password);
          const token = await cred.user.getIdToken();
          apiClient.setAuthToken(token);
          return;
        } catch (signInErr: any) {
          // Mot de passe incorrect pour ce compte existant
          throw Object.assign(new Error('auth/mediscan-email-exists-signin'), { code: 'auth/mediscan-email-exists-signin' });
        }
      }
      throw err;
    }
  }, []);

  const updateProfile = useCallback(async (updates: { displayName?: string; photoURL?: string }) => {
    const auth = authRef.current;
    const mod = authModuleRef.current;
    if (!auth?.currentUser || !mod) throw new Error('Auth not initialized');
    await mod.updateProfile(auth.currentUser, updates);
    setUser((prev) => prev ? { ...prev, ...updates } : null);
    try {
      const token = await auth.currentUser.getIdToken(true);
      apiClient.setAuthToken(token);
    } catch (e) {
      console.error('Failed to refresh token:', e);
    }
  }, []);

  const signInWithGoogle = useCallback(async () => {
    const auth = authRef.current;
    const mod = authModuleRef.current;
    if (!auth || !mod) throw new Error('Auth not initialized');
    const provider = new mod.GoogleAuthProvider();
    const isMobile = /iPhone|iPad|iPod|Android/i.test(navigator.userAgent);

    if (isMobile) {
      try {
        const credential = await mod.signInWithPopup(auth, provider);
        const token = await credential.user.getIdToken();
        apiClient.setAuthToken(token);
      } catch (popupErr: any) {
        if (popupErr?.code === 'auth/popup-blocked' || popupErr?.code === 'auth/cancelled-popup-request' || popupErr?.code === 'auth/popup-closed-by-user') {
          await mod.signInWithRedirect(auth, provider);
        } else {
          throw popupErr;
        }
      }
      return;
    }
    const credential = await mod.signInWithPopup(auth, provider);
    const token = await credential.user.getIdToken();
    apiClient.setAuthToken(token);
  }, []);

  const signInAnonymously = useCallback(async () => {
    const auth = authRef.current;
    const mod = authModuleRef.current;
    if (!auth || !mod) throw new Error('Auth not initialized');
    const credential = await mod.signInAnonymously(auth);
    const token = await credential.user.getIdToken();
    apiClient.setAuthToken(token);
  }, []);

  const signOut = useCallback(async () => {
    const auth = authRef.current;
    const mod = authModuleRef.current;
    if (!auth || !mod) return;
    await mod.signOut(auth);
    setUser(null);
    if (typeof window !== 'undefined') {
      sessionStorage.removeItem('auth_token');
    }
  }, []);

  const getIdToken = useCallback(async (): Promise<string | null> => {
    const auth = authRef.current;
    if (!auth?.currentUser) return null;
    try {
      const token = await auth.currentUser.getIdToken(true);
      apiClient.setAuthToken(token);
      return token;
    } catch {
      return null;
    }
  }, []);

  return (
    <AuthContext.Provider value={{ user, loading, signIn, signUp, signInWithGoogle, signInAnonymously, signOut, getIdToken, updateProfile }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}

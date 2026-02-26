'use client';

import React from 'react';
import { X, AlertCircle, Heart } from 'lucide-react';
import { useCredits } from '@/contexts/CreditsContext';
import { useAuth } from '@/lib/auth/AuthContext';
import { useLanguage } from '@/contexts/LanguageContext';

interface CreditsModalProps {
  isOpen: boolean;
  onClose: () => void;
  action: 'scan' | 'chat';
  cost: number;
}

export function CreditsModal({ isOpen, onClose, action, cost }: CreditsModalProps) {
  const { credits } = useCredits();
  const { user, signOut } = useAuth();
  const { t } = useLanguage();

  if (!isOpen) return null;

  const isTrial = user?.isAnonymous;
  const actionName = action === 'scan' ? 'scanner un médicament' : 'utiliser le chat IA';

  if (isTrial) {
    return (
      <div className="fixed inset-0 bg-black/50 dark:bg-black/60 backdrop-blur-sm flex items-center justify-center z-[9999] p-4">
        <div className="bg-white dark:bg-gray-800 rounded-3xl p-6 max-w-md w-full shadow-xl border border-gray-200 dark:border-gray-700">
          <div className="flex justify-end mb-2">
            <button
              onClick={onClose}
              className="w-10 h-10 rounded-xl bg-gray-100 dark:bg-gray-700 flex items-center justify-center hover:bg-gray-200 dark:hover:bg-gray-600 transition-colors"
            >
              <X className="w-5 h-5 text-text-secondary dark:text-gray-300" />
            </button>
          </div>
          <div className="text-center pt-2">
            <div className="inline-flex w-12 h-12 rounded-full bg-primary/10 dark:bg-blue-900/30 items-center justify-center mb-4">
              <Heart className="w-6 h-6 text-primary dark:text-blue-400" strokeWidth={1.5} />
            </div>
            <h3 className="text-lg font-semibold text-text-primary dark:text-gray-100 mb-2">
              {t('upgradeTitle')}
            </h3>
            <p className="text-sm text-text-secondary dark:text-gray-400 leading-relaxed mb-6">
              {t('upgradeMessage')}
            </p>
            <button
              type="button"
              onClick={() => { onClose(); signOut(); }}
              className="w-full py-3 rounded-xl font-semibold bg-primary text-white hover:opacity-95 transition-all"
            >
              {t('upgradeCta')}
            </button>
            <button
              type="button"
              onClick={onClose}
              className="mt-3 text-sm text-text-secondary dark:text-gray-400 hover:underline"
            >
              {t('back')}
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="fixed inset-0 bg-black/80 dark:bg-black/90 backdrop-blur-sm flex items-center justify-center z-[9999] p-4">
      <div className="bg-white dark:bg-gray-800 rounded-3xl p-6 max-w-md w-full shadow-2xl border border-orange-200 dark:border-orange-800/50">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-xl font-bold text-text-primary dark:text-gray-100">
            Crédits insuffisants
          </h3>
          <button
            onClick={onClose}
            className="w-10 h-10 rounded-xl bg-gray-100 dark:bg-gray-700 flex items-center justify-center hover:bg-gray-200 dark:hover:bg-gray-600 transition-colors"
          >
            <X className="w-5 h-5 text-text-secondary dark:text-gray-300" />
          </button>
        </div>
        <div className="bg-orange-50 dark:bg-orange-900/20 rounded-2xl p-4 border border-orange-200 dark:border-orange-800/50">
          <div className="flex items-start gap-3">
            <AlertCircle className="w-5 h-5 text-orange-600 dark:text-orange-400 mt-0.5 flex-shrink-0" />
            <div>
              <p className="text-sm text-text-primary dark:text-gray-200">
                Pour {actionName}, il vous faut <span className="font-semibold">{cost} gemmes</span>. Vous avez <span className="font-semibold">{credits} gemmes</span>. Revenez demain pour votre quota journalier.
              </p>
            </div>
          </div>
        </div>
        <button
          onClick={onClose}
          className="w-full mt-4 px-4 py-3 rounded-xl bg-gray-100 dark:bg-gray-700 text-text-secondary dark:text-gray-300 font-semibold hover:bg-gray-200 dark:hover:bg-gray-600 transition-colors"
        >
          Fermer
        </button>
      </div>
    </div>
  );
}

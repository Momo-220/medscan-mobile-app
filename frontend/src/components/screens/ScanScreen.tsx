'use client';

import React, { useState, useRef, useEffect } from 'react';
import { Button } from '@/components/ui/Button';
import { OrganicWaveLoader } from '@/components/ui/Loading';
import { ArrowLeft, Upload, X, Camera, Settings } from 'lucide-react';
import { apiClient } from '@/lib/api/client';
import { useAuth } from '@/lib/auth/AuthContext';
import { useNavigation } from '@/lib/navigation/NavigationContext';
import { useLanguage } from '@/contexts/LanguageContext';
import { useHealth } from '@/contexts/HealthContext';
import { ScanResult } from '@/types';
import { ScanResultScreen } from './ScanResultScreen';
import { ScanningScreen } from './ScanningScreen';
import { CameraPhotoCapture } from '@/components/features/CameraPhotoCapture';
import { CreditsModal } from '@/components/ui/CreditsModal';
import { useCredits } from '@/contexts/CreditsContext';

export function ScanScreen() {
  const { getIdToken } = useAuth();
  const { navigateTo, goBack, setCameraOverlayOpen } = useNavigation();
  const { refreshCredits } = useCredits();
  const { refreshStats } = useHealth();
  const { t, language } = useLanguage();
  const [step, setStep] = useState<'upload' | 'analyzing' | 'result'>('upload');
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [scanResult, setScanResult] = useState<ScanResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [showCameraCapture, setShowCameraCapture] = useState(false);
  const [showCreditsModal, setShowCreditsModal] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    setCameraOverlayOpen(showCameraCapture);
    return () => setCameraOverlayOpen(false);
  }, [showCameraCapture, setCameraOverlayOpen]);

  const handleFileSelect = async (file: File) => {
    if (!file.type.startsWith('image/')) {
      setError(t('scanError'));
      return;
    }

    if (file.size > 10 * 1024 * 1024) {
      setError(t('scanError'));
      return;
    }

    setSelectedFile(file);
    setPreviewUrl(URL.createObjectURL(file));
    setError(null);
    
    // Démarrer automatiquement l'analyse après l'upload
    setTimeout(() => {
      handleScan(file);
    }, 500); // Petit délai pour l'UX
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    const file = e.dataTransfer.files[0];
    if (file) handleFileSelect(file);
  };

  const handleScan = async (file?: File) => {
    const fileToScan = file || selectedFile;
    if (!fileToScan) return;

    try {
      setStep('analyzing');
      setError(null);

      // S'assurer qu'on a un token Firebase valide AVANT d'appeler le backend
      const token = await getIdToken();
      if (!token) {
        setError(t('authErrorGeneric') || 'Veuillez vous reconnecter pour scanner un médicament.');
        setStep('upload');
        return;
      }

      const result = await apiClient.scanMedication(fileToScan, language);
      setScanResult(result);
      setStep('result');
      const { analytics } = await import('@/lib/analytics');
      analytics.scan();
      // Rafraîchir les crédits et stats après succès
      await Promise.all([
        refreshCredits(),
        refreshStats(),
      ]);
    } catch (err: any) {
      // Gérer l'erreur 402 (crédits insuffisants)
      if (err.response?.status === 402) {
        setShowCreditsModal(true);
        setStep('upload');
        return;
      }

      // L'erreur sera automatiquement affichée via l'intercepteur API
      // On garde juste le message pour l'affichage local si nécessaire
      const errorMessage = err.response?.data?.detail || 
                           err.response?.data?.error || 
                           err.message ||
                           t('scanError');
      
      setError(errorMessage);
      setStep('upload');
    }
  };

  const handleBack = () => {
    if (step === 'result') {
      setStep('upload');
      setScanResult(null);
    } else {
      goBack();
    }
  };

  const handleCameraCapture = (file: File) => {
    setShowCameraCapture(false);
    setSelectedFile(file);
    setPreviewUrl(URL.createObjectURL(file));
    setError(null);
    setStep('analyzing');
    handleScan(file);
  };

  if (showCameraCapture) {
    return (
      <CameraPhotoCapture
        onCapture={handleCameraCapture}
        onClose={() => setShowCameraCapture(false)}
      />
    );
  }

  if (step === 'result' && scanResult) {
    return <ScanResultScreen result={scanResult} />;
  }

  return (
    <div className="min-h-screen min-h-[100dvh] w-full max-w-full overflow-x-hidden bg-background pb-[calc(8rem+env(safe-area-inset-bottom))] pt-[env(safe-area-inset-top)] relative z-10 flex flex-col">
      {/* Header - Responsive */}
      <div className="px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto w-full pt-8 pb-6 flex items-center gap-4">
        <button
          onClick={handleBack}
          className="p-2 hover:bg-white/50 rounded-full"
        >
          <ArrowLeft className="w-5 h-5 sm:w-6 sm:h-6 text-text-primary" />
        </button>
        <h1 className="text-xl sm:text-2xl font-bold text-text-primary">
          {t('scanMedication')}
        </h1>
      </div>

      {/* Content - Centered */}
      {step === 'upload' && (
        <>
          {/* Consigne visuelle - Responsive */}
          <div className="px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto w-full mb-6">
            <div className="card p-4 bg-gradient-to-r from-primary/5 to-primary/10 border border-primary/20">
              <p className="text-text-primary text-sm font-medium text-center">
                📸 {t('scanMethodTitle')}
              </p>
              <p className="text-text-secondary text-xs text-center mt-1">
                {t('scanMethodSubtitle')}
              </p>
            </div>
          </div>

          <div className="flex-1 flex items-center justify-center px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto w-full">
            {/* Boutons côte à côte sur mobile et desktop */}
            <div className="flex flex-row gap-4">
              {/* Bouton Upload - Coloré */}
              <div className="w-40 h-44 sm:w-48 sm:h-52">
                <div
                  onDrop={handleDrop}
                  onDragOver={(e) => e.preventDefault()}
                  className="bg-gradient-to-br from-blue-500 to-blue-600 rounded-3xl p-4 sm:p-6 w-full h-full text-center cursor-pointer flex flex-col items-center justify-center shadow-lg hover:shadow-xl hover:scale-[1.02] transition-all"
                  onClick={() => fileInputRef.current?.click()}
                >
                  {previewUrl ? (
                    <div className="relative w-full h-full flex items-center justify-center">
                      <img
                        src={previewUrl}
                        alt="Preview"
                        className="max-w-full max-h-full rounded-xl shadow-md object-contain"
                      />
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          setSelectedFile(null);
                          setPreviewUrl(null);
                        }}
                        className="absolute top-1 right-1 p-1.5 bg-white/95 backdrop-blur-sm text-red-500 rounded-full hover:bg-white shadow-md transition-all"
                      >
                        <X className="w-3 h-3" />
                      </button>
                    </div>
                  ) : (
                    <>
                      <div className="w-14 h-14 sm:w-16 sm:h-16 mb-3 rounded-2xl bg-white/20 flex items-center justify-center">
                        <Upload className="w-7 h-7 sm:w-8 sm:h-8 text-white" strokeWidth={2} />
                      </div>
                      <p className="text-white font-bold text-sm sm:text-base mb-1">
                        {t('uploadPhoto')}
                      </p>
                      <p className="text-white/80 text-xs">
                        JPEG/PNG
                      </p>
                    </>
                  )}
                </div>
              </div>

              {/* Bouton Caméra - Prendre une photo */}
              <div className="w-40 h-44 sm:w-48 sm:h-52">
                <button
                  onClick={() => setShowCameraCapture(true)}
                  className="bg-gradient-to-br from-purple-500 to-purple-600 rounded-3xl p-4 sm:p-6 w-full h-full text-center cursor-pointer flex flex-col items-center justify-center shadow-lg hover:shadow-xl hover:scale-[1.02] transition-all"
                >
                  <div className="w-14 h-14 sm:w-16 sm:h-16 mb-3 rounded-2xl bg-white/20 flex items-center justify-center">
                    <Camera className="w-7 h-7 sm:w-8 sm:h-8 text-white" strokeWidth={2} />
                  </div>
                  <p className="text-white font-bold text-sm sm:text-base mb-1">
                    {t('takePhoto')}
                  </p>
                  <p className="text-white/80 text-xs">
                    {t('cameraThenAnalyze')}
                  </p>
                </button>
              </div>
            </div>
          </div>

          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            className="hidden"
            onChange={(e) => {
              const file = e.target.files?.[0];
              if (file) handleFileSelect(file);
            }}
          />

          {error && (
            <div className="px-6 pb-6">
              <div className="p-4 bg-red-50/90 backdrop-blur-sm border border-red-200/60 rounded-2xl shadow-sm">
                <p className="text-red-600 text-sm font-medium">{error}</p>
              </div>
            </div>
          )}
        </>
      )}

      {step === 'analyzing' && (
        <ScanningScreen previewUrl={previewUrl} />
      )}

      {/* Credits Modal */}
      <CreditsModal
        isOpen={showCreditsModal}
        onClose={() => {
          setShowCreditsModal(false);
          refreshCredits();
        }}
        action="scan"
        cost={5}
      />

      {/* Bottom Navigation Bar */}
      <nav className="fixed bottom-[30px] left-6 right-6 max-w-2xl mx-auto">
        <div className="relative">
          <div className="relative bg-white rounded-[40px] h-[85px] shadow-[0_10px_40px_rgba(26,59,93,0.06)]">
            <div className="flex items-center justify-around h-full px-6 relative z-10">
              <NavItem icon="home" active={false} onClick={() => navigateTo('home')} />
              <NavItem icon="search" active={false} />
              <div className="w-[68px]"></div>
              <NavItem icon="bell" active={false} />
              <NavItem icon="settings" active={false} />
            </div>
            <svg
              className="absolute bottom-0 left-1/2 -translate-x-1/2 pointer-events-none"
              width="100"
              height="30"
              viewBox="0 0 100 30"
              preserveAspectRatio="none"
              style={{ filter: 'drop-shadow(0 -2px 8px rgba(26, 59, 93, 0.06))' }}
            >
              <path
                d="M 0 30 L 0 20 C 20 20, 30 10, 50 10 C 70 10, 80 20, 100 20 L 100 30 Z"
                fill="white"
              />
            </svg>
          </div>
          <button
            onClick={() => navigateTo('scan')}
            className="absolute left-1/2 -translate-x-1/2 -top-[34px] w-[68px] h-[68px] bg-gradient-to-r from-[#5B9FED] to-[#3B7FD4] rounded-full shadow-[0_4px_20px_rgba(91,159,237,0.4)] flex items-center justify-center z-20"
          >
            <svg className="w-7 h-7 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={3}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M12 4v16m8-8H4" />
            </svg>
          </button>
        </div>
      </nav>
    </div>
  );
}

function NavItem({ icon, active, onClick }: { icon: string; active: boolean; onClick?: () => void }) {
  const iconSize = "w-7 h-7";
  
  const icons = {
    home: (
      <svg 
        className={iconSize} 
        fill={active ? "#5B9FED" : "none"} 
        stroke={active ? "#5B9FED" : "rgba(91, 159, 237, 0.25)"} 
        viewBox="0 0 24 24"
        strokeWidth={active ? 0 : 2}
      >
        <path strokeLinecap="round" strokeLinejoin="round" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
      </svg>
    ),
    search: (
      <svg 
        className={iconSize} 
        fill="none" 
        stroke="rgba(91, 159, 237, 0.25)" 
        viewBox="0 0 24 24"
        strokeWidth={2}
      >
        <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
      </svg>
    ),
    bell: (
      <svg 
        className={iconSize} 
        fill="none" 
        stroke="rgba(91, 159, 237, 0.25)" 
        viewBox="0 0 24 24"
        strokeWidth={2}
      >
        <path strokeLinecap="round" strokeLinejoin="round" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
      </svg>
    ),
    settings: (
      <Settings 
        className={iconSize} 
        stroke="rgba(91, 159, 237, 0.25)" 
        strokeWidth={2}
      />
    ),
  };

  return (
    <button 
      className="flex flex-col items-center justify-center relative"
      onClick={onClick}
    >
      {icons[icon as keyof typeof icons]}
      {active && (
        <div className="absolute top-[38px] w-1 h-1 rounded-full bg-primary"></div>
      )}
    </button>
  );
}


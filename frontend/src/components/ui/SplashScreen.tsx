'use client';

import React, { useEffect, useState } from 'react';
import Image from 'next/image';

interface SplashScreenProps {
  onComplete: () => void;
  duration?: number; // Durée en ms (défaut 2500ms)
}

export function SplashScreen({ onComplete, duration = 2500 }: SplashScreenProps) {
  const [animationPhase, setAnimationPhase] = useState<'pop-in' | 'visible' | 'pop-out'>('pop-in');
  const [stars, setStars] = useState<Array<{left: number, top: number, opacity: number, duration: number, delay: number}>>([]);

  // Générer les positions des étoiles uniquement côté client pour éviter l'erreur d'hydratation
  useEffect(() => {
    const starsData = [...Array(20)].map(() => ({
      left: Math.random() * 100,
      top: Math.random() * 100,
      opacity: Math.random() * 0.4 + 0.1,
      duration: 2 + Math.random() * 2,
      delay: Math.random() * 2,
    }));
    setStars(starsData);
  }, []);

  useEffect(() => {
    // Phase 1: Pop-in (0 -> 600ms)
    const visibleTimer = setTimeout(() => {
      setAnimationPhase('visible');
    }, 600);

    // Phase 2: Pop-out (duration - 600ms)
    const popOutTimer = setTimeout(() => {
      setAnimationPhase('pop-out');
    }, duration - 600);

    // Phase 3: Terminer
    const completeTimer = setTimeout(() => {
      onComplete();
    }, duration);

    return () => {
      clearTimeout(visibleTimer);
      clearTimeout(popOutTimer);
      clearTimeout(completeTimer);
    };
  }, [duration, onComplete]);

  return (
    <div
      className="fixed inset-0 z-[100] flex flex-col items-center justify-center w-full max-w-full overflow-x-hidden min-h-[100dvh]"
      style={{
        background: 'linear-gradient(135deg, #0a1628 0%, #1a365d 50%, #0d2847 100%)',
      }}
    >
      {/* Étoiles/particules en arrière-plan */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        {stars.map((star, i) => (
          <div
            key={i}
            className="absolute w-1 h-1 bg-white rounded-full"
            style={{
              left: `${star.left}%`,
              top: `${star.top}%`,
              opacity: star.opacity,
              animation: `twinkle ${star.duration}s ease-in-out infinite`,
              animationDelay: `${star.delay}s`,
            }}
          />
        ))}
      </div>

      {/* Logo Container avec animation pop */}
      <div 
        className={`relative flex flex-col items-center transition-all ease-out ${
          animationPhase === 'pop-in' 
            ? 'scale-0 opacity-0' 
            : animationPhase === 'visible' 
            ? 'scale-100 opacity-100' 
            : 'scale-0 opacity-0'
        }`}
        style={{
          transitionDuration: animationPhase === 'pop-in' ? '0ms' : '500ms',
          transitionTimingFunction: animationPhase === 'pop-out' ? 'ease-in' : 'cubic-bezier(0.34, 1.56, 0.64, 1)',
        }}
      >
        {/* Cercle lumineux derrière le logo */}
        <div 
          className={`absolute w-64 h-64 rounded-full bg-gradient-to-r from-primary/40 to-cyan-500/40 blur-3xl transition-all duration-500 ${
            animationPhase === 'visible' ? 'scale-100 opacity-100' : 'scale-50 opacity-0'
          }`}
        />
        
        {/* Logo LCP: next/image + priority pour chargement immédiat */}
        <div className="relative z-10">
          <Image
            src="/logo.png"
            alt="MediScan"
            width={160}
            height={160}
            className="w-40 h-40 object-contain drop-shadow-2xl"
            priority
            fetchPriority="high"
          />
          <div 
            className="hidden w-40 h-40 rounded-3xl bg-gradient-to-br from-primary to-cyan-500 items-center justify-center shadow-2xl"
          >
            <svg 
              className="w-20 h-20 text-white" 
              fill="none" 
              viewBox="0 0 24 24" 
              stroke="currentColor"
            >
              <path 
                strokeLinecap="round" 
                strokeLinejoin="round" 
                strokeWidth={2} 
                d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" 
              />
            </svg>
          </div>
        </div>
      </div>

      {/* Styles pour les animations */}
      <style jsx>{`
        @keyframes twinkle {
          0%, 100% { opacity: 0.1; }
          50% { opacity: 0.6; }
        }
      `}</style>
    </div>
  );
}

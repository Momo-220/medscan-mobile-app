'use client';

import React, { useState, useEffect } from 'react';
import { 
  Camera, 
  Globe, 
  ShieldCheck, 
  Activity, 
  Heart, 
  Search, 
  CheckCircle, 
  Users, 
  Star, 
  Sparkles,
  Menu,
  X,
  ArrowRight,
  ChevronDown,
  Info,
  AlertTriangle,
  RefreshCw,
  Bookmark,
  Brain,
  Shield
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

export default function Home() {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [activeStep, setActiveStep] = useState(1);
  const [screenshotErrors, setScreenshotErrors] = useState<Record<number, boolean>>({});
  const [frameError, setFrameError] = useState(false);

  // Intersection Observer for fluid scroll-reveal animations
  useEffect(() => {
    if (typeof window !== 'undefined') {
      const runObserver = () => {
        const observer = new IntersectionObserver(
          (entries) => {
            entries.forEach((entry) => {
              if (entry.isIntersecting) {
                entry.target.classList.add('opacity-100', 'translate-y-0');
                entry.target.classList.remove('opacity-0', 'translate-y-8');
                observer.unobserve(entry.target); // Stop observing once visible
              }
            });
          },
          { 
            threshold: 0.02,
            rootMargin: '0px 0px -20px 0px'
          }
        );

        const targets = document.querySelectorAll('.reveal-on-scroll');
        targets.forEach((target) => observer.observe(target));
      };

      // Delay to ensure Next.js client-side hydration has completed
      const timer = setTimeout(runObserver, 150);
      return () => clearTimeout(timer);
    }
  }, []);

  const steps = [
    {
      id: 1,
      title: "1. Scannez l'emballage",
      desc: "Cadrez simplement la boîte de médicament avec l'appareil photo. Notre technologie OCR de pointe analyse l'emballage sous tous ses angles.",
      phoneView: (
        <div className="w-full h-full bg-slate-900 flex flex-col justify-between p-4 relative overflow-hidden text-white font-sans">
          {/* Camera View Area */}
          <div className="absolute inset-0 bg-[url('https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?q=80&w=600')] bg-cover bg-center opacity-60"></div>
          
          {/* Scanning Box Overlay */}
          <div className="absolute inset-x-8 top-28 bottom-28 border-2 border-dashed border-blue-500 rounded-2xl flex items-center justify-center">
            {/* Laser Line */}
            <div className="absolute left-0 right-0 h-1 bg-gradient-to-r from-transparent via-blue-400 to-transparent shadow-lg shadow-blue-500/50 animate-pulse" style={{ animationDuration: '1.5s', top: '45%' }}></div>
            <span className="text-[10px] tracking-wider font-bold bg-blue-600/80 px-2.5 py-1 rounded-full uppercase absolute top-4 backdrop-blur-sm">Aligner le texte</span>
          </div>

          {/* Camera UI Top */}
          <div className="z-10 flex justify-between items-center">
            <span className="text-xs font-bold bg-black/40 px-3 py-1.5 rounded-full backdrop-blur-sm flex items-center gap-1.5">
              <Camera className="w-3.5 h-3.5 text-blue-400" /> Mode Auto
            </span>
            <div className="w-2.5 h-2.5 rounded-full bg-green-500 animate-ping"></div>
          </div>

          {/* Camera UI Bottom */}
          <div className="z-10 text-center space-y-3">
            <p className="text-xs bg-black/60 py-2 px-4 rounded-xl inline-block backdrop-blur-sm">
              Analyse visuelle en cours...
            </p>
            <div className="flex justify-center items-center gap-6 pb-2">
              <div className="w-10 h-10 rounded-full bg-white/10 flex items-center justify-center border border-white/20">
                <Bookmark className="w-4 h-4 text-white" />
              </div>
              <div className="w-16 h-16 rounded-full bg-white border-4 border-slate-300/40 flex items-center justify-center active:scale-95 transition-transform">
                <div className="w-12 h-12 rounded-full bg-blue-600"></div>
              </div>
              <div className="w-10 h-10 rounded-full bg-white/10 flex items-center justify-center border border-white/20">
                <RefreshCw className="w-4 h-4 text-white" />
              </div>
            </div>
          </div>
        </div>
      )
    },
    {
      id: 2,
      title: "2. Analyse Moléculaire",
      desc: "L'IA MedScan décortique la composition, identifie le principe actif principal (comme le paracétamol), et vérifie son dosage précis.",
      phoneView: (
        <div className="w-full h-full bg-slate-950 flex flex-col justify-between p-5 text-slate-100 font-sans">
          {/* Header */}
          <div className="flex items-center justify-between border-b border-slate-800 pb-3">
            <span className="text-sm font-extrabold tracking-tight bg-gradient-to-r from-blue-400 to-indigo-400 bg-clip-text text-transparent">Analyse Active</span>
            <span className="text-[10px] font-bold bg-blue-950 text-blue-400 border border-blue-800/50 px-2 py-0.5 rounded-full">
              Fiabilité 98%
            </span>
          </div>

          {/* Molecule Card */}
          <div className="my-auto space-y-4">
            <div className="bg-slate-900/80 border border-slate-800 rounded-2xl p-4 space-y-3">
              <div className="flex items-center gap-2.5">
                <div className="w-8 h-8 rounded-lg bg-blue-600/20 border border-blue-500/30 flex items-center justify-center">
                  <Activity className="w-4.5 h-4.5 text-blue-400" />
                </div>
                <div>
                  <h4 className="text-xs text-slate-400 font-bold uppercase tracking-wider">Molécule Détectée</h4>
                  <p className="text-sm font-extrabold text-white">Paracétamol</p>
                </div>
              </div>
              <div className="w-full bg-slate-800 rounded-full h-1.5 overflow-hidden">
                <div className="bg-blue-500 h-1.5 rounded-full w-[98%]"></div>
              </div>
            </div>

            <div className="bg-slate-900/80 border border-slate-800 rounded-2xl p-4 space-y-2">
              <h4 className="text-xs text-slate-400 font-bold uppercase tracking-wider">Classification</h4>
              <p className="text-xs font-semibold text-slate-200">Antalgique / Antipyrétique (soulagement de la douleur et fièvre)</p>
              <div className="mt-2.5 bg-blue-950/40 border border-blue-900/30 rounded-xl p-2.5 flex items-start gap-2">
                <Info className="w-3.5 h-3.5 text-blue-400 shrink-0 mt-0.5" />
                <span className="text-[10px] text-blue-300 leading-normal">Dosage standard : 500mg à 1000mg par prise. Maximum 4g par jour.</span>
              </div>
            </div>
          </div>

          {/* Footer CTA */}
          <button className="w-full py-2.5 bg-blue-600 hover:bg-blue-700 text-xs font-bold rounded-xl text-center shadow-lg shadow-blue-500/20">
            Valider & Continuer
          </button>
        </div>
      )
    },
    {
      id: 3,
      title: "3. Traduction Médicale",
      desc: "Une notice à l'étranger ? MedScan traduit instantanément les précautions d'emploi et la posologie dans votre langue natale de façon ultra-simplifiée.",
      phoneView: (
        <div className="w-full h-full bg-slate-950 flex flex-col justify-between p-5 text-slate-100 font-sans">
          {/* Header */}
          <div className="flex items-center justify-between border-b border-slate-800 pb-3">
            <span className="text-sm font-extrabold tracking-tight flex items-center gap-1.5">
              <Globe className="w-4 h-4 text-indigo-400" /> Traduction
            </span>
            <div className="flex items-center gap-1 bg-slate-900 px-2 py-0.5 rounded-full text-[9px] border border-slate-800">
              <span className="text-slate-400">ES</span>
              <span className="text-blue-400">➔</span>
              <span className="text-white font-bold">FR</span>
            </div>
          </div>

          {/* Translation Content */}
          <div className="my-auto space-y-3">
            <div className="bg-slate-900/50 border border-slate-800/80 rounded-xl p-3.5">
              <h4 className="text-[9px] text-slate-500 font-bold uppercase tracking-wider mb-1">Texte Original (Espagnol)</h4>
              <p className="text-xs italic text-slate-400 leading-relaxed">"No exceder la dosis recomendada de 4 gramos al día. Tomar con agua."</p>
            </div>
            
            <div className="flex justify-center">
              <div className="bg-indigo-600 text-white rounded-full p-1 shadow-md shadow-indigo-600/30">
                <RefreshCw className="w-3.5 h-3.5" />
              </div>
            </div>

            <div className="bg-indigo-950/20 border border-indigo-900/30 rounded-xl p-3.5">
              <h4 className="text-[9px] text-indigo-400 font-bold uppercase tracking-wider mb-1">Traduction Simplifiée (Français)</h4>
              <p className="text-xs text-slate-100 font-medium leading-relaxed">"Ne dépassez pas la dose maximale de 4 grammes par jour. À avaler avec un grand verre d'eau."</p>
            </div>
          </div>

          {/* Language selection simulation */}
          <div className="grid grid-cols-3 gap-2 text-center text-[10px] font-bold">
            <span className="py-2 rounded-lg bg-slate-900 border border-slate-800 text-slate-300">English</span>
            <span className="py-2 rounded-lg bg-indigo-600/20 border border-indigo-500/30 text-indigo-300">Français</span>
            <span className="py-2 rounded-lg bg-slate-900 border border-slate-800 text-slate-300">Deutsch</span>
          </div>
        </div>
      )
    },
    {
      id: 4,
      title: "4. Contrôle de Sécurité",
      desc: "L'application compare le scan avec votre historique pour détecter d'éventuels risques de double dosage ou d'interactions dangereuses.",
      phoneView: (
        <div className="w-full h-full bg-slate-950 flex flex-col justify-between p-5 text-slate-100 font-sans">
          {/* Header */}
          <div className="flex items-center justify-between border-b border-slate-800 pb-3">
            <span className="text-sm font-extrabold tracking-tight flex items-center gap-1.5 text-rose-400">
              <ShieldCheck className="w-4 h-4" /> Sécurité
            </span>
            <span className="text-[9px] font-bold bg-rose-950 text-rose-400 border border-rose-800/40 px-2 py-0.5 rounded-full">
              Risque Détecté
            </span>
          </div>

          {/* Alert Area */}
          <div className="my-auto space-y-4">
            <div className="bg-rose-950/30 border border-rose-900/40 rounded-2xl p-4 text-center space-y-3">
              <div className="w-12 h-12 rounded-full bg-rose-900/30 border border-rose-500/30 flex items-center justify-center mx-auto">
                <AlertTriangle className="w-6 h-6 text-rose-400" />
              </div>
              <div className="space-y-1">
                <h4 className="text-sm font-extrabold text-rose-300">Alerte Double Dosage</h4>
                <p className="text-xs text-rose-200/80 leading-normal">Vous avez déjà scanné du <strong>Doliprane</strong> il y a 2 heures.</p>
              </div>
            </div>

            <div className="bg-slate-900/60 border border-slate-800/80 rounded-xl p-3.5 space-y-2">
              <h5 className="text-[10px] text-slate-400 font-bold uppercase tracking-wider">Recommandation</h5>
              <p className="text-xs text-slate-300 leading-normal">
                Attendez au moins <strong>4 heures</strong> entre chaque prise de Paracétamol pour éviter tout surdosage hépatique.
              </p>
            </div>
          </div>

          {/* Emergency Button Simulation */}
          <button className="w-full py-2.5 bg-rose-600 hover:bg-rose-700 text-xs font-bold rounded-xl text-center shadow-lg shadow-rose-500/20">
            Enregistrer dans mon profil
          </button>
        </div>
      )
    }
  ];

  return (
    <div 
      className="min-h-screen text-slate-900 transition-colors relative overflow-x-hidden"
      style={{ background: 'radial-gradient(circle at 50% 30%, #D2E9FC 0%, #EBF4FD 45%, #FFFFFF 100%)' }}
    >
      
      {/* 1. NAVBAR */}
      <nav className="sticky top-0 z-50 backdrop-blur-md bg-white/30 border-b border-blue-100/50 transition-all">
        <div className="max-w-7xl mx-auto px-6 h-20 flex items-center justify-between">
          
          {/* Logo */}
          <div className="flex items-center space-x-2.5">
            <img 
              src="/logo.png" 
              alt="Medscan Logo" 
              className="h-11 w-auto object-contain"
            />
            <span className="text-2xl sm:text-3xl font-black tracking-tight text-slate-900 dark:text-white font-sans">
              Medscan.
            </span>
          </div>

          {/* Desktop Menu */}
          <div className="hidden md:flex items-center space-x-8">
            <a href="#features" className="text-sm font-semibold text-slate-600 dark:text-slate-300 hover:text-blue-600 dark:hover:text-blue-400 transition-colors">Fonctionnalités</a>
            <a href="#how-it-works" className="text-sm font-semibold text-slate-600 dark:text-slate-300 hover:text-blue-600 dark:hover:text-blue-400 transition-colors">Démo Interactive</a>
            <a href="#testimonials" className="text-sm font-semibold text-slate-600 dark:text-slate-300 hover:text-blue-600 dark:hover:text-blue-400 transition-colors">Avis</a>
            <a href="#faq" className="text-sm font-semibold text-slate-600 dark:text-slate-300 hover:text-blue-600 dark:hover:text-blue-400 transition-colors">FAQ</a>
          </div>

          {/* Right Action Menu - Clean Download CTA */}
          <div className="hidden md:flex items-center">
            <a 
              href="#hero"
              className="px-5 py-2.5 rounded-full text-sm font-bold text-white bg-gradient-to-r from-blue-600 to-blue-700 hover:from-blue-700 hover:to-blue-800 shadow-md shadow-blue-500/20 hover:shadow-lg transition-all"
            >
              Télécharger l'App
            </a>
          </div>

          {/* Mobile Menu Toggle */}
          <div className="flex md:hidden items-center">
            <button 
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)} 
              className="p-2 text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg"
              aria-label="Toggle menu"
            >
              {mobileMenuOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
            </button>
          </div>
        </div>

        {/* Mobile Menu dropdown */}
        {mobileMenuOpen && (
          <div className="md:hidden border-t border-slate-200/50 dark:border-slate-800/50 bg-white dark:bg-slate-900 px-6 py-6 space-y-4 shadow-xl">
            <a 
              href="#features" 
              onClick={() => setMobileMenuOpen(false)}
              className="block text-base font-semibold text-slate-600 dark:text-slate-300 hover:text-blue-600"
            >
              Fonctionnalités
            </a>
            <a 
              href="#how-it-works" 
              onClick={() => setMobileMenuOpen(false)}
              className="block text-base font-semibold text-slate-600 dark:text-slate-300 hover:text-blue-600"
            >
              Démo Interactive
            </a>
            <a 
              href="#testimonials" 
              onClick={() => setMobileMenuOpen(false)}
              className="block text-base font-semibold text-slate-600 dark:text-slate-300 hover:text-blue-600"
            >
              Avis
            </a>
            <a 
              href="#faq" 
              onClick={() => setMobileMenuOpen(false)}
              className="block text-base font-semibold text-slate-600 dark:text-slate-300 hover:text-blue-600"
            >
              FAQ
            </a>
          </div>
        )}
      </nav>

      {/* 2. HERO SECTION - Centered & Premium layout */}
      <section id="hero" className="relative pt-16 pb-0 px-6 overflow-hidden">
        {/* Background glow effects */}
        <div className="absolute top-20 left-1/2 -translate-x-1/2 w-[600px] h-[600px] rounded-full bg-blue-500/10 dark:bg-blue-500/5 blur-[120px] -z-10" />
        <div className="absolute top-40 right-10 w-[300px] h-[300px] rounded-full bg-indigo-500/10 dark:bg-indigo-500/5 blur-[80px] -z-10" />

        <div className="max-w-4xl mx-auto flex flex-col items-center text-center space-y-10 relative z-10">
          
          {/* Headline */}
          <h1 className="text-4xl sm:text-5xl md:text-6xl font-black tracking-tight leading-[1.1] text-slate-900 dark:text-white max-w-3xl">
            Scannez n'importe quel médicament. <br />
            <span className="bg-gradient-to-r from-blue-600 to-indigo-500 bg-clip-text text-transparent dark:from-blue-400 dark:to-indigo-400">
              Partout dans le monde.
            </span>
          </h1>

          {/* Subtext */}
          <p className="text-base sm:text-lg text-slate-600 dark:text-slate-400 max-w-2xl font-medium leading-relaxed">
            Une seule photo suffit pour comprendre son utilisation, sa posologie, ses précautions et bien plus encore.
          </p>

          {/* Badges de téléchargement */}
          <div className="flex flex-wrap items-center justify-center gap-6 pt-2">
            <a 
              href="#" 
              className="flex items-center justify-center px-8 py-3.5 rounded-full bg-[#030712] hover:bg-black text-white border border-slate-800 transition-all shadow-lg active:scale-95"
            >
              <img 
                src="https://upload.wikimedia.org/wikipedia/commons/3/3c/Download_on_the_App_Store_Badge.svg" 
                alt="Télécharger dans l'App Store" 
                className="h-8 w-auto object-contain"
              />
            </a>
            <a 
              href="#" 
              className="flex items-center justify-center px-8 py-3.5 rounded-full bg-[#030712] hover:bg-black text-white border border-slate-800 transition-all shadow-lg active:scale-95"
            >
              <img 
                src="https://upload.wikimedia.org/wikipedia/commons/7/78/Google_Play_Store_badge_EN.svg" 
                alt="Télécharger dans le Google Play" 
                className="h-8 w-auto object-contain"
              />
            </a>
          </div>

          {/* Centered Image Mockup Underneath */}
          <div className="w-full max-w-4xl mt-4 relative flex justify-center">
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[400px] h-[400px] rounded-full bg-blue-500/10 blur-3xl -z-10" />
            
            {/* Left Floating Cards (Visible on lg screens) */}
            
            {/* Left Floating Cards (Visible on lg screens) */}
            
            {/* L1: Scan Intelligent */}
            <div className="hidden lg:flex flex-col absolute lg:left-[-10px] xl:left-[-40px] 2xl:left-[-80px] lg:top-[12%] xl:top-[10%] w-56 backdrop-blur-lg bg-white/40 dark:bg-slate-900/50 border border-white/40 dark:border-slate-800/60 rounded-2xl p-3.5 shadow-2xl z-20 text-left space-y-2">
              {/* macOS window dots */}
              <div className="flex space-x-1.5 pb-1">
                <span className="w-2.5 h-2.5 rounded-full bg-rose-500"></span>
                <span className="w-2.5 h-2.5 rounded-full bg-amber-500"></span>
                <span className="w-2.5 h-2.5 rounded-full bg-emerald-500"></span>
              </div>
              <div className="flex items-center space-x-2">
                <div className="w-7 h-7 rounded-lg bg-blue-500/20 flex items-center justify-center text-blue-600">
                  <Camera className="w-4 h-4" />
                </div>
                <h4 className="text-xs font-bold text-slate-800 dark:text-white">Scan Intelligent</h4>
              </div>
              <p className="text-[10px] text-slate-500 dark:text-slate-400 font-medium leading-relaxed">
                Identifiez instantanément vos boîtes de médicaments avec une simple photo.
              </p>
            </div>

            {/* L2: Traduction de Notice */}
            <div className="hidden lg:flex flex-col absolute lg:left-[-30px] xl:left-[-60px] 2xl:left-[-110px] lg:top-[42%] xl:top-[40%] w-56 backdrop-blur-lg bg-white/40 dark:bg-slate-900/50 border border-white/40 dark:border-slate-800/60 rounded-2xl p-3.5 shadow-2xl z-20 text-left space-y-2">
              <div className="flex space-x-1.5 pb-1">
                <span className="w-2.5 h-2.5 rounded-full bg-rose-500"></span>
                <span className="w-2.5 h-2.5 rounded-full bg-amber-500"></span>
                <span className="w-2.5 h-2.5 rounded-full bg-emerald-500"></span>
              </div>
              <div className="flex items-center space-x-2">
                <div className="w-7 h-7 rounded-lg bg-indigo-500/20 flex items-center justify-center text-indigo-600">
                  <Globe className="w-4 h-4" />
                </div>
                <h4 className="text-xs font-bold text-slate-800 dark:text-white">Traduction de Notice</h4>
              </div>
              <p className="text-[10px] text-slate-500 dark:text-slate-400 font-medium leading-relaxed">
                Traduisez et comprenez les contre-indications dans 4 langues.
              </p>
            </div>

            {/* L3: Prévention & Dosage */}
            <div className="hidden lg:flex flex-col absolute lg:left-[-10px] xl:left-[-30px] 2xl:left-[-60px] lg:top-[72%] xl:top-[70%] w-56 backdrop-blur-lg bg-white/40 dark:bg-slate-900/50 border border-white/40 dark:border-slate-800/60 rounded-2xl p-3.5 shadow-2xl z-20 text-left space-y-2">
              <div className="flex space-x-1.5 pb-1">
                <span className="w-2.5 h-2.5 rounded-full bg-rose-500"></span>
                <span className="w-2.5 h-2.5 rounded-full bg-amber-500"></span>
                <span className="w-2.5 h-2.5 rounded-full bg-emerald-500"></span>
              </div>
              <div className="flex items-center space-x-2">
                <div className="w-7 h-7 rounded-lg bg-rose-500/20 flex items-center justify-center text-rose-600">
                  <ShieldCheck className="w-4 h-4" />
                </div>
                <h4 className="text-xs font-bold text-slate-800 dark:text-white">Alerte Dosage</h4>
              </div>
              <p className="text-[10px] text-slate-500 dark:text-slate-400 font-medium leading-relaxed">
                Évitez les risques de double-dosage et les interactions médicamenteuses.
              </p>
            </div>

            {/* Right Floating Cards (Visible on lg screens) */}

            {/* R1: Assistant IA Santé */}
            <div className="hidden lg:flex flex-col absolute lg:right-[-15px] xl:right-[-35px] 2xl:right-[-75px] lg:top-[14%] xl:top-[12%] w-56 backdrop-blur-lg bg-white/40 dark:bg-slate-900/50 border border-white/40 dark:border-slate-800/60 rounded-2xl p-3.5 shadow-2xl z-20 text-left space-y-2">
              <div className="flex space-x-1.5 pb-1">
                <span className="w-2.5 h-2.5 rounded-full bg-rose-500"></span>
                <span className="w-2.5 h-2.5 rounded-full bg-amber-500"></span>
                <span className="w-2.5 h-2.5 rounded-full bg-emerald-500"></span>
              </div>
              <div className="flex items-center space-x-2">
                <div className="w-7 h-7 rounded-lg bg-emerald-500/20 flex items-center justify-center text-emerald-600">
                  <Sparkles className="w-4 h-4" />
                </div>
                <h4 className="text-xs font-bold text-slate-800 dark:text-white">Assistant IA Santé</h4>
              </div>
              <p className="text-[10px] text-slate-500 dark:text-slate-400 font-medium leading-relaxed">
                Posez vos questions sur la prise de médicaments et vos traitements en direct.
              </p>
            </div>

            {/* R2: Rappels de Prise */}
            <div className="hidden lg:flex flex-col absolute lg:right-[-35px] xl:right-[-55px] 2xl:right-[-95px] lg:top-[44%] xl:top-[42%] w-56 backdrop-blur-lg bg-white/40 dark:bg-slate-900/50 border border-white/40 dark:border-slate-800/60 rounded-2xl p-3.5 shadow-2xl z-20 text-left space-y-2">
              <div className="flex space-x-1.5 pb-1">
                <span className="w-2.5 h-2.5 rounded-full bg-rose-500"></span>
                <span className="w-2.5 h-2.5 rounded-full bg-amber-500"></span>
                <span className="w-2.5 h-2.5 rounded-full bg-emerald-500"></span>
              </div>
              <div className="flex items-center space-x-2">
                <div className="w-7 h-7 rounded-lg bg-purple-500/20 flex items-center justify-center text-purple-600">
                  <Activity className="w-4 h-4" />
                </div>
                <h4 className="text-xs font-bold text-slate-800 dark:text-white">Rappels de Prise</h4>
              </div>
              <p className="text-[10px] text-slate-500 dark:text-slate-400 font-medium leading-relaxed">
                Planifiez vos rappels journaliers et suivez votre traitement en toute sérénité.
              </p>
            </div>

            {/* R3: Profil & Avatar */}
            <div className="hidden lg:flex flex-col absolute lg:right-[-10px] xl:right-[-30px] 2xl:right-[-60px] lg:top-[74%] xl:top-[72%] w-56 backdrop-blur-lg bg-white/40 dark:bg-slate-900/50 border border-white/40 dark:border-slate-800/60 rounded-2xl p-3.5 shadow-2xl z-20 text-left space-y-2">
              <div className="flex space-x-1.5 pb-1">
                <span className="w-2.5 h-2.5 rounded-full bg-rose-500"></span>
                <span className="w-2.5 h-2.5 rounded-full bg-amber-500"></span>
                <span className="w-2.5 h-2.5 rounded-full bg-emerald-500"></span>
              </div>
              <div className="flex items-center space-x-2">
                <div className="w-7 h-7 rounded-lg bg-pink-500/20 flex items-center justify-center text-pink-600">
                  <Users className="w-4 h-4" />
                </div>
                <h4 className="text-xs font-bold text-slate-800 dark:text-white">Profil & Avatar</h4>
              </div>
              <p className="text-[10px] text-slate-500 dark:text-slate-400 font-medium leading-relaxed">
                Configurez votre profil de santé, votre avatar et suivez vos statistiques d'utilisation.
              </p>
            </div>

            <img 
              src="/hero_mockup.png" 
              alt="MedScan App Interface" 
              className="w-full max-w-3xl h-auto object-contain drop-shadow-2xl"
            />
          </div>
        </div>
      </section>

      {/* 4. KEY FEATURES - Scroll Reveal */}
      <section id="features" className="reveal-on-scroll opacity-0 translate-y-8 transition-all duration-700 ease-out pt-6 pb-20 px-6 bg-slate-50/50 dark:bg-slate-900/20">
        <div className="max-w-7xl mx-auto flex flex-col space-y-10">
          
          <div className="text-center flex flex-col space-y-4 max-w-2xl mx-auto">
            <span className="text-xs font-bold text-blue-600 dark:text-blue-400 uppercase tracking-widest">Fonctionnalités intelligentes</span>
            <h2 className="text-3xl sm:text-4xl font-extrabold tracking-tight text-slate-900 dark:text-white">
              Une assistance complète dans votre poche
            </h2>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
            
            {/* Feature 1 */}
            <div className="bg-white dark:bg-slate-900 p-6 rounded-3xl border border-slate-200/50 dark:border-slate-800/80 shadow-sm hover:shadow-md transition-all group hover:-translate-y-1 duration-300">
              <div className="mb-5 flex items-center justify-center w-16 h-16 rounded-2xl bg-blue-50 dark:bg-blue-950/40 group-hover:scale-105 transition-transform">
                <img src="/icon_scan.png" alt="Scan Intelligent" className="w-12 h-12 object-contain" />
              </div>
              <h3 className="text-lg font-bold text-slate-900 dark:text-white mb-2">Scan Intelligent</h3>
              <p className="text-sm text-slate-500 dark:text-slate-400 leading-relaxed font-medium">
                Pointez simplement l'appareil photo vers la boîte de médicaments. MedScan détecte le nom et la posologie automatiquement.
              </p>
            </div>

            {/* Feature 2 */}
            <div className="bg-white dark:bg-slate-900 p-6 rounded-3xl border border-slate-200/50 dark:border-slate-800/80 shadow-sm hover:shadow-md transition-all group hover:-translate-y-1 duration-300">
              <div className="mb-5 flex items-center justify-center w-16 h-16 rounded-2xl bg-indigo-50 dark:bg-indigo-950/40 group-hover:scale-105 transition-transform">
                <img src="/icon_translation.png" alt="Traduction Simplifiée" className="w-12 h-12 object-contain" />
              </div>
              <h3 className="text-lg font-bold text-slate-900 dark:text-white mb-2">Traduction Simplifiée</h3>
              <p className="text-sm text-slate-500 dark:text-slate-400 leading-relaxed font-medium">
                Idéal pour les voyages. Traduit les contre-indications, les précautions d'emploi et les posologies dans 4 langues.
              </p>
            </div>

            {/* Feature 3 */}
            <div className="bg-white dark:bg-slate-900 p-6 rounded-3xl border border-slate-200/50 dark:border-slate-800/80 shadow-sm hover:shadow-md transition-all group hover:-translate-y-1 duration-300">
              <div className="mb-5 flex items-center justify-center w-16 h-16 rounded-2xl bg-rose-50 dark:bg-rose-950/40 group-hover:scale-105 transition-transform">
                <img src="/icon_info.png" alt="Prévention Posologie" className="w-12 h-12 object-contain" />
              </div>
              <h3 className="text-lg font-bold text-slate-900 dark:text-white mb-2">Prévention Posologie</h3>
              <p className="text-sm text-slate-500 dark:text-slate-400 leading-relaxed font-medium">
                Évitez les risques de double-dosage accidentels en enregistrant vos scans et en recevant des alertes d'interactions médicamenteuses.
              </p>
            </div>

            {/* Feature 4 */}
            <div className="bg-white dark:bg-slate-900 p-6 rounded-3xl border border-slate-200/50 dark:border-slate-800/80 shadow-sm hover:shadow-md transition-all group hover:-translate-y-1 duration-300">
              <div className="mb-5 flex items-center justify-center w-16 h-16 rounded-2xl bg-green-50 dark:bg-green-950/40 group-hover:scale-105 transition-transform">
                <img src="/icon_profile.png" alt="Assistant IA Santé" className="w-12 h-12 object-contain" />
              </div>
              <h3 className="text-lg font-bold text-slate-900 dark:text-white mb-2">Assistant IA Santé</h3>
              <p className="text-sm text-slate-500 dark:text-slate-400 leading-relaxed font-medium">
                Posez vos questions sur la prise d'un traitement à notre assistant IA intelligent sécurisé et obtenez des réponses explicatives instantanées.
              </p>
            </div>

          </div>

        </div>
      </section>

      {/* 5. INTERACTIVE SMARTPHONE SHOWCASE - Redesigned Apple-Style (French) */}
      <section id="how-it-works" className="py-24 px-6 bg-white dark:bg-slate-950 relative overflow-hidden">
        {/* Abstract background blur glows */}
        <div className="absolute top-1/3 left-1/4 w-[500px] h-[500px] rounded-full bg-blue-400/5 blur-[120px] -z-10" />
        <div className="absolute bottom-1/3 right-1/4 w-[400px] h-[400px] rounded-full bg-indigo-400/5 blur-[100px] -z-10" />

        <div className="max-w-7xl mx-auto flex flex-col space-y-20">
          
          {/* Section Title Block */}
          <div className="text-center flex flex-col space-y-4 max-w-3xl mx-auto">
            <span className="text-xs font-bold text-blue-600 dark:text-blue-400 uppercase tracking-[0.2em] font-mono">
              COMMENT FONCTIONNE MEDSCAN
            </span>
            <h2 className="text-3xl sm:text-5xl font-black tracking-tight text-slate-900 dark:text-white leading-tight">
              Comprendre vos médicaments n'a jamais été aussi simple.
            </h2>
            <p className="text-base sm:text-lg text-slate-500 dark:text-slate-400 max-w-2xl mx-auto font-medium">
              Prenez une photo. MedScan vous explique tout ce que vous devez savoir en un instant.
            </p>
          </div>

          {/* Interactive Layout Grid */}
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 lg:gap-16 items-center">
            
            {/* Left side - 4 Interactive Steps Cards */}
            <div className="lg:col-span-6 flex flex-col space-y-5">
              {[
                {
                  id: 1,
                  icon: <Camera className="w-5 h-5" />,
                  title: "Scannez votre médicament",
                  description: "Pointez simplement votre appareil photo vers la boîte de médicaments ou la plaquette."
                },
                {
                  id: 2,
                  icon: <Brain className="w-5 h-5" />,
                  title: "L'IA analyse instantanément",
                  description: "MedScan identifie le médicament et extrait les informations clés en quelques secondes."
                },
                {
                  id: 3,
                  icon: <Globe className="w-5 h-5" />,
                  title: "Lisez dans votre langue",
                  description: "Traduisez les notices médicales complexes en langage clair et simple (4 langues supportées)."
                },
                {
                  id: 4,
                  icon: <Shield className="w-5 h-5" />,
                  title: "Prenez en toute sécurité",
                  description: "Recevez des alertes personnalisées de posologie, d'interactions et de contre-indications."
                }
              ].map((step) => {
                const isActive = activeStep === step.id;
                return (
                  <motion.div
                    key={step.id}
                    onClick={() => setActiveStep(step.id)}
                    onMouseEnter={() => setActiveStep(step.id)}
                    className={`group p-6 rounded-3xl border text-left cursor-pointer transition-all duration-300 relative flex items-start space-x-5 overflow-hidden ${
                      isActive 
                        ? 'bg-blue-50/50 dark:bg-slate-900 border-blue-500/30 shadow-md shadow-blue-500/5' 
                        : 'bg-transparent border-transparent hover:border-slate-200 dark:hover:border-slate-800'
                    }`}
                    whileHover={{ y: -2, scale: 1.01 }}
                    transition={{ type: "spring", stiffness: 300, damping: 20 }}
                  >
                    {/* Active Background Glow */}
                    {isActive && (
                      <div className="absolute inset-0 bg-radial-gradient from-blue-500/5 via-transparent to-transparent pointer-events-none -z-10" />
                    )}

                    {/* Icon container */}
                    <div className={`w-11 h-11 rounded-2xl flex items-center justify-center shrink-0 transition-all duration-300 ${
                      isActive 
                        ? 'bg-blue-600 text-white shadow-md shadow-blue-500/20 rotate-6' 
                        : 'bg-slate-100 text-slate-500 dark:bg-slate-800 dark:text-slate-400 group-hover:rotate-6'
                    }`}>
                      {step.icon}
                    </div>

                    <div className="space-y-1">
                      <h3 className={`text-base font-bold transition-colors ${
                        isActive ? 'text-blue-600 dark:text-blue-400' : 'text-slate-900 dark:text-slate-200'
                      }`}>
                        {step.title}
                      </h3>
                      <p className="text-xs sm:text-sm text-slate-500 dark:text-slate-400 leading-relaxed font-medium">
                        {step.description}
                      </p>
                    </div>
                  </motion.div>
                );
              })}
            </div>

            {/* Right side - Large animated smartphone mockup with floating tags */}
            <div className="lg:col-span-6 flex justify-center items-center relative py-6 lg:py-12 w-full">
              
              {/* Centered relative wrapper to contain both phone and floating tags close together */}
              <div className="relative w-full max-w-[420px] aspect-[9/16] flex justify-center items-center">
                
                {/* Floating glassmorphic info tags orbiting the mockup */}
                <div className="absolute inset-0 pointer-events-none z-20">
                  {[
                    { text: "Dosage", pos: "left-[2%] top-[12%]", delay: 0 },
                    { text: "Effets Secondaires", pos: "left-[-10%] top-[42%]", delay: 0.5 },
                    { text: "Interactions Médicamenteuses", pos: "left-[0%] top-[72%]", delay: 1 },
                    { text: "Précautions", pos: "right-[2%] top-[16%]", delay: 0.25 },
                    { text: "Alerte Grossesse", pos: "right-[-10%] top-[46%]", delay: 0.75 },
                    { text: "Principe Actif", pos: "right-[0%] top-[76%]", delay: 1.25 }
                  ].map((tag, idx) => (
                    <motion.div
                      key={idx}
                      className={`hidden md:flex absolute ${tag.pos} backdrop-blur-md bg-white/60 dark:bg-slate-900/60 border border-white/40 dark:border-slate-800/40 shadow-lg px-4 py-2 rounded-full text-xs font-bold text-slate-800 dark:text-white items-center space-x-1.5`}
                      animate={{ y: [0, idx % 2 === 0 ? -10 : 10, 0] }}
                      transition={{ repeat: Infinity, duration: 4 + idx * 0.3, ease: "easeInOut", delay: tag.delay }}
                    >
                      <span className="text-emerald-500 font-extrabold">✓</span>
                      <span>{tag.text}</span>
                    </motion.div>
                  ))}
                </div>

                {/* iPhone Mockup Frame */}
                <motion.div 
                  className={`relative w-full max-w-[310px] aspect-[9/18.5] flex items-center justify-center z-10 ${
                    screenshotErrors[activeStep]
                      ? 'rounded-[3.2rem] bg-slate-950 p-2.5 shadow-2xl border-[6px] border-slate-900 overflow-hidden'
                      : ''
                  }`}
                initial={{ scale: 0.9, opacity: 0 }}
                whileInView={{ scale: 1, opacity: 1 }}
                viewport={{ once: true }}
                transition={{ duration: 0.8, ease: "easeOut" }}
              >
                {/* Speaker Grill & Camera Notch (Only for fallback view) */}
                {screenshotErrors[activeStep] && (
                  <div className="absolute top-2 inset-x-0 h-6 bg-black z-40 rounded-b-xl flex justify-center items-center pointer-events-none">
                    <div className="w-16 h-4 bg-slate-900 rounded-full flex justify-center items-center">
                      <div className="w-2.5 h-2.5 rounded-full bg-slate-950 border border-slate-800 mr-2"></div>
                      <div className="w-1.5 h-1.5 rounded-full bg-slate-950 border border-slate-800"></div>
                    </div>
                  </div>
                )}

                {/* Simulated Screen Content - Dynamic Image Screenshots with Animation Fallbacks */}
                <div className={`overflow-hidden flex flex-col justify-between ${
                  screenshotErrors[activeStep]
                    ? 'w-full h-full rounded-[2.8rem] bg-slate-900 relative p-4 pt-10'
                    : 'w-full h-full relative rounded-[2.8rem]'
                }`}>
                  <AnimatePresence mode="wait">
                    {!screenshotErrors[activeStep] ? (
                      <motion.img 
                        key={`screenshot-${activeStep}`}
                        src={
                          activeStep === 1 ? '/screenshots/scan.png' :
                          activeStep === 2 ? '/screenshots/analysis.png' :
                          activeStep === 3 ? '/screenshots/translation.png' :
                          '/screenshots/safety.png'
                        }
                        alt={`Capture d'écran MedScan - Étape ${activeStep}`}
                        className="absolute inset-0 w-full h-full object-contain select-none z-30 filter drop-shadow-2xl"
                        onError={() => setScreenshotErrors(prev => ({ ...prev, [activeStep]: true }))}
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        exit={{ opacity: 0 }}
                        transition={{ duration: 0.4 }}
                      />
                    ) : (
                      activeStep === 1 ? (
                        <motion.div 
                          key="step1-fallback"
                          className="w-full h-full flex flex-col justify-between items-center text-center relative"
                          initial={{ opacity: 0 }}
                          animate={{ opacity: 1 }}
                          exit={{ opacity: 0 }}
                          transition={{ duration: 0.4 }}
                        >
                          <div className="absolute inset-0 bg-gradient-to-b from-blue-500/10 to-indigo-500/10 rounded-2xl flex flex-col items-center justify-center p-4 border border-blue-500/20">
                            {/* Corner focus brackets */}
                            <div className="absolute top-4 left-4 w-6 h-6 border-t-2 border-l-2 border-blue-500 rounded-tl-md animate-pulse"></div>
                            <div className="absolute top-4 right-4 w-6 h-6 border-t-2 border-r-2 border-blue-500 rounded-tr-md animate-pulse"></div>
                            <div className="absolute bottom-4 left-4 w-6 h-6 border-b-2 border-l-2 border-blue-500 rounded-bl-md animate-pulse"></div>
                            <div className="absolute bottom-4 right-4 w-6 h-6 border-b-2 border-r-2 border-blue-500 rounded-br-md animate-pulse"></div>

                            {/* Laser Scan line */}
                            <motion.div 
                              className="absolute left-4 right-4 h-0.5 bg-gradient-to-r from-transparent via-blue-500 to-transparent shadow-lg shadow-blue-500"
                              animate={{ top: ["10%", "90%", "10%"] }}
                              transition={{ repeat: Infinity, duration: 3, ease: "easeInOut" }}
                            />

                            {/* OCR scanning highlight text block */}
                            <div className="space-y-2 w-full px-6 opacity-30 mt-6">
                              <div className="h-2.5 bg-white/20 rounded w-3/4 mx-auto"></div>
                              <div className="h-2.5 bg-blue-500/40 rounded w-5/6 mx-auto animate-pulse"></div>
                              <div className="h-2.5 bg-white/20 rounded w-2/3 mx-auto"></div>
                            </div>

                            <div className="my-auto z-10">
                              <Camera className="w-12 h-12 text-blue-500 mx-auto mb-3 animate-pulse" />
                              <p className="text-[10px] text-blue-400 font-bold uppercase tracking-wider bg-blue-500/10 px-3 py-1 rounded-full border border-blue-500/20">
                                Mode Caméra Actif
                              </p>
                            </div>

                            <div className="z-10 mt-auto text-slate-400 font-mono text-[9px] select-none text-center leading-relaxed">
                              <span className="block font-sans text-[11px] font-bold text-white mb-0.5">[ Écran de Scan IA ]</span>
                              Déposez public/screenshots/scan.png
                            </div>
                          </div>
                        </motion.div>
                      ) : activeStep === 2 ? (
                        <motion.div 
                          key="step2-fallback"
                          className="w-full h-full flex flex-col justify-between items-center text-center relative"
                          initial={{ opacity: 0 }}
                          animate={{ opacity: 1 }}
                          exit={{ opacity: 0 }}
                          transition={{ duration: 0.4 }}
                        >
                          <div className="absolute inset-0 bg-gradient-to-b from-indigo-500/10 to-purple-500/10 rounded-2xl flex flex-col items-center justify-center p-4 border border-indigo-500/20">
                            
                            {/* Pulsing AI particles glow */}
                            <div className="absolute w-24 h-24 rounded-full bg-indigo-500/15 blur-xl animate-ping" />

                            <div className="my-auto z-10 space-y-4">
                              <Brain className="w-12 h-12 text-indigo-500 mx-auto animate-pulse" />
                              <div className="space-y-1">
                                <p className="text-[10px] text-indigo-400 font-bold uppercase tracking-wider bg-indigo-500/10 px-3 py-1 rounded-full border border-indigo-500/20 w-fit mx-auto">
                                  Analyse IA en cours
                                </p>
                                <p className="text-[11px] font-bold text-white">Précision de Détection : 99.4%</p>
                              </div>
                            </div>

                            <div className="z-10 mt-auto text-slate-400 font-mono text-[9px] select-none text-center leading-relaxed">
                              <span className="block font-sans text-[11px] font-bold text-white mb-0.5">[ Écran Fiche Molécule ]</span>
                              Déposez public/screenshots/analysis.png
                            </div>
                          </div>
                        </motion.div>
                      ) : activeStep === 3 ? (
                        <motion.div 
                          key="step3-fallback"
                          className="w-full h-full flex flex-col justify-between items-center text-center relative"
                          initial={{ opacity: 0 }}
                          animate={{ opacity: 1 }}
                          exit={{ opacity: 0 }}
                          transition={{ duration: 0.4 }}
                        >
                          <div className="absolute inset-0 bg-gradient-to-b from-purple-500/10 to-pink-500/10 rounded-2xl flex flex-col items-center justify-center p-4 border border-purple-500/20">
                            
                            <div className="my-auto z-10 space-y-3">
                              <motion.div
                                animate={{ rotate: 360 }}
                                transition={{ repeat: Infinity, duration: 15, ease: "linear" }}
                                className="w-12 h-12 mx-auto flex items-center justify-center text-purple-500"
                              >
                                <Globe className="w-10 h-10" />
                              </motion.div>
                              <p className="text-[10px] text-purple-400 font-bold uppercase tracking-wider bg-purple-500/10 px-3 py-1 rounded-full border border-purple-500/20 w-fit mx-auto">
                                Traduction Active
                              </p>
                              <div className="text-[11px] font-bold text-white space-y-1">
                                <div>Traduit en Direct</div>
                                <div className="text-[9px] text-slate-400">(4 langues supportées)</div>
                              </div>
                            </div>

                            <div className="z-10 mt-auto text-slate-400 font-mono text-[9px] select-none text-center leading-relaxed">
                              <span className="block font-sans text-[11px] font-bold text-white mb-0.5">[ Écran de Traduction ]</span>
                              Déposez public/screenshots/translation.png
                            </div>
                          </div>
                        </motion.div>
                      ) : (
                        <motion.div 
                          key="step4-fallback"
                          className="w-full h-full flex flex-col justify-between items-center text-center relative"
                          initial={{ opacity: 0 }}
                          animate={{ opacity: 1 }}
                          exit={{ opacity: 0 }}
                          transition={{ duration: 0.4 }}
                        >
                          <div className="absolute inset-0 bg-gradient-to-b from-emerald-500/10 to-teal-500/10 rounded-2xl flex flex-col items-center justify-center p-4 border border-emerald-500/20">
                            
                            <div className="my-auto z-10 space-y-3">
                              <Shield className="w-12 h-12 text-emerald-500 mx-auto animate-pulse" />
                              <p className="text-[10px] text-emerald-400 font-bold uppercase tracking-wider bg-emerald-500/10 px-3 py-1 rounded-full border border-emerald-500/20 w-fit mx-auto">
                                Contrôle de Sécurité
                              </p>
                              <p className="text-[11px] font-bold text-white">Calculateur de Posologie & Risques</p>
                            </div>

                            <div className="z-10 mt-auto text-slate-400 font-mono text-[9px] select-none text-center leading-relaxed">
                              <span className="block font-sans text-[11px] font-bold text-white mb-0.5">[ Écran Alerte & Posologie ]</span>
                              Déposez public/screenshots/safety.png
                            </div>
                          </div>
                        </motion.div>
                      )
                    )}
                  </AnimatePresence>

                  {/* Bottom indicator */}
                  <div className="w-24 h-1 bg-black/60 dark:bg-white/30 rounded-full absolute bottom-2 left-1/2 -translate-x-1/2 z-40 pointer-events-none"></div>
                </div>
              </motion.div>
            </div>
          </div>
        </div>
      </div>
      </section>

      {/* 7. TESTIMONIALS - Scroll Reveal */}
      <section id="testimonials" className="reveal-on-scroll opacity-0 translate-y-8 transition-all duration-700 ease-out py-20 px-6 bg-white dark:bg-slate-950">
        <div className="max-w-7xl mx-auto flex flex-col space-y-16">
          
          <div className="flex flex-col space-y-4 max-w-2xl">
            <span className="text-xs font-bold text-blue-600 dark:text-blue-400 uppercase tracking-widest">Avis Utilisateurs</span>
            <h2 className="text-3xl sm:text-4xl font-extrabold tracking-tight text-slate-900 dark:text-white">
              Ils sécurisent leur santé avec MedScan
            </h2>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            
            {/* Testimonial 1 */}
            <div className="bg-slate-50/50 dark:bg-slate-900/30 p-6 rounded-3xl border border-slate-200/50 dark:border-slate-800/80 flex flex-col justify-between space-y-6">
              <p className="text-sm text-slate-600 dark:text-slate-300 italic leading-relaxed">
                "Voyager à l'étranger avec mes enfants était stressant pour l'achat de médicaments. MedScan m'a permis de scanner les boîtes locales en Italie et d'avoir la traduction exacte des composants. Indispensable !"
              </p>
              <div className="flex items-center space-x-3">
                <div className="w-10 h-10 rounded-full bg-blue-100 dark:bg-blue-900/50 text-blue-600 dark:text-blue-400 font-bold flex items-center justify-center text-xs">
                  SM
                </div>
                <div>
                  <h4 className="text-xs font-bold text-slate-900 dark:text-slate-200">Sarah Martin</h4>
                  <span className="text-[10px] text-slate-400">Maman de 2 enfants</span>
                </div>
              </div>
            </div>

            {/* Testimonial 2 */}
            <div className="bg-slate-50/50 dark:bg-slate-900/30 p-6 rounded-3xl border border-slate-200/50 dark:border-slate-800/80 flex flex-col justify-between space-y-6">
              <p className="text-sm text-slate-600 dark:text-slate-300 italic leading-relaxed">
                "En tant que pharmacien, je conseille souvent des patients qui voyagent. MedScan les aide à comprendre les notices et posologies dans leur langue directement sur leur smartphone. Un outil d'accompagnement génial."
              </p>
              <div className="flex items-center space-x-3">
                <div className="w-10 h-10 rounded-full bg-blue-100 dark:bg-blue-900/50 text-blue-600 dark:text-blue-400 font-bold flex items-center justify-center text-xs">
                  DK
                </div>
                <div>
                  <h4 className="text-xs font-bold text-slate-900 dark:text-slate-200">David K.</h4>
                  <span className="text-[10px] text-slate-400">Pharmacien d'officine</span>
                </div>
              </div>
            </div>

            {/* Testimonial 3 */}
            <div className="bg-slate-50/50 dark:bg-slate-900/30 p-6 rounded-3xl border border-slate-200/50 dark:border-slate-800/80 flex flex-col justify-between space-y-6">
              <p className="text-sm text-slate-600 dark:text-slate-300 italic leading-relaxed">
                "L'assistant IA médical est extraordinaire. Il répond de manière simple et rassurante à des questions comme 'puis-je prendre ce médicament avec du jus de pamplemousse ?' avec des explications claires."
              </p>
              <div className="flex items-center space-x-3">
                <div className="w-10 h-10 rounded-full bg-blue-100 dark:bg-blue-900/50 text-blue-600 dark:text-blue-400 font-bold flex items-center justify-center text-xs">
                  LN
                </div>
                <div>
                  <h4 className="text-xs font-bold text-slate-900 dark:text-slate-200">Lucie N.</h4>
                  <span className="text-[10px] text-slate-400">Étudiante en soins infirmiers</span>
                </div>
              </div>
            </div>

          </div>

        </div>
      </section>

      {/* 8. FAQ ACCORDION SECTION - Scroll Reveal */}
      <section id="faq" className="reveal-on-scroll opacity-0 translate-y-8 transition-all duration-700 ease-out py-20 px-6 bg-slate-50/50 dark:bg-slate-900/20">
        <div className="max-w-4xl mx-auto flex flex-col space-y-12">
          
          <div className="text-center flex flex-col space-y-4">
            <span className="text-xs font-bold text-blue-600 dark:text-blue-400 uppercase tracking-widest">Des réponses à vos questions</span>
            <h2 className="text-3xl font-extrabold tracking-tight text-slate-900 dark:text-white">
              Questions Fréquentes
            </h2>
          </div>

          <div className="space-y-4">
            {/* FAQ Item 1 */}
            <details className="group bg-white dark:bg-slate-900 border border-slate-200/50 dark:border-slate-800/80 rounded-2xl p-5 [&_summary::-webkit-details-marker]:hidden">
              <summary className="flex justify-between items-center font-bold text-base sm:text-lg cursor-pointer list-none text-slate-900 dark:text-white">
                <span>Comment fonctionne le scan de boîte ?</span>
                <span className="transition-transform group-open:rotate-180 text-blue-500">
                  <ChevronDown className="w-5 h-5" />
                </span>
              </summary>
              <p className="text-sm text-slate-500 dark:text-slate-400 mt-3 leading-relaxed font-medium">
                Pointez simplement l'appareil photo de l'application mobile vers l'emballage. Notre système détecte instantanément le texte, identifie le nom de marque, le dosage et la molécule active, puis compare ces données avec nos bases officielles pour générer une fiche simplifiée.
              </p>
            </details>

            {/* FAQ Item 2 */}
            <details className="group bg-white dark:bg-slate-900 border border-slate-200/50 dark:border-slate-800/80 rounded-2xl p-5 [&_summary::-webkit-details-marker]:hidden">
              <summary className="flex justify-between items-center font-bold text-base sm:text-lg cursor-pointer list-none text-slate-900 dark:text-white">
                <span>Mes données de santé sont-elles sécurisées ?</span>
                <span className="transition-transform group-open:rotate-180 text-blue-500">
                  <ChevronDown className="w-5 h-5" />
                </span>
              </summary>
              <p className="text-sm text-slate-500 dark:text-slate-400 mt-3 leading-relaxed font-medium">
                Oui, totalement. Vos scans et votre historique sont enregistrés de façon sécurisée. MedScan respecte scrupuleusement la confidentialité de vos données et n'envoie aucune information médicale nominative à des tiers.
              </p>
            </details>

            {/* FAQ Item 3 */}
            <details className="group bg-white dark:bg-slate-900 border border-slate-200/50 dark:border-slate-800/80 rounded-2xl p-5 [&_summary::-webkit-details-marker]:hidden">
              <summary className="flex justify-between items-center font-bold text-base sm:text-lg cursor-pointer list-none text-slate-900 dark:text-white">
                <span>L'application remplace-t-elle un avis médical ?</span>
                <span className="transition-transform group-open:rotate-180 text-blue-500">
                  <ChevronDown className="w-5 h-5" />
                </span>
              </summary>
              <p className="text-sm text-slate-500 dark:text-slate-400 mt-3 leading-relaxed font-medium">
                Absolument pas. MedScan est un outil informatif d'accompagnement visant à simplifier la compréhension des notices et prévenir les erreurs de base. En cas de doute, d'effet indésirable ou d'urgence médicale, vous devez impérativement consulter un médecin ou un pharmacien.
              </p>
            </details>

            {/* FAQ Item 4 */}
            <details className="group bg-white dark:bg-slate-900 border border-slate-200/50 dark:border-slate-800/80 rounded-2xl p-5 [&_summary::-webkit-details-marker]:hidden">
              <summary className="flex justify-between items-center font-bold text-base sm:text-lg cursor-pointer list-none text-slate-900 dark:text-white">
                <span>L'application fonctionne-t-elle hors-ligne ?</span>
                <span className="transition-transform group-open:rotate-180 text-blue-500">
                  <ChevronDown className="w-5 h-5" />
                </span>
              </summary>
              <p className="text-sm text-slate-500 dark:text-slate-400 mt-3 leading-relaxed font-medium">
                Oui. Une fois qu'un médicament a été scanné, sa fiche simplifiée est stockée localement dans l'historique de votre application. Vous pouvez y accéder et relire les détails à tout moment, même sans connexion réseau active (dans un avion ou à l'étranger sans données mobiles).
              </p>
            </details>
          </div>

        </div>
      </section>

      {/* 9. DOWNLOAD CTA BANNER - Scroll Reveal */}
      <section className="reveal-on-scroll opacity-0 translate-y-8 transition-all duration-700 ease-out py-16 px-6">
        <div className="max-w-6xl mx-auto rounded-[36px] bg-gradient-to-r from-blue-700 to-indigo-600 p-8 sm:p-10 lg:py-8 lg:px-16 flex flex-col lg:flex-row items-center justify-center gap-12 lg:gap-24 relative overflow-hidden shadow-xl shadow-blue-500/10">
          <div className="absolute top-[-50px] right-[-50px] w-96 h-96 rounded-full bg-white/5 blur-3xl"></div>

          {/* Left Text */}
          <div className="text-center lg:text-left flex flex-col space-y-6 max-w-xl text-white">
            <h2 className="text-3xl sm:text-4xl font-extrabold tracking-tight leading-tight">
              Prenez soin de votre santé dès aujourd'hui
            </h2>
            <p className="text-sm sm:text-base text-white/80 leading-relaxed font-medium">
              Téléchargez gratuitement l'application MedScan et simplifiez l'utilisation de vos médicaments en un clin d'œil.
            </p>
            <div className="flex flex-wrap justify-center lg:justify-start gap-4 pt-2">
              <a 
                href="#" 
                className="flex items-center justify-center px-6 py-2.5 rounded-full bg-[#030712] hover:bg-black text-white border border-white/10 transition-all shadow-lg active:scale-95"
              >
                <img 
                  src="https://upload.wikimedia.org/wikipedia/commons/3/3c/Download_on_the_App_Store_Badge.svg" 
                  alt="App Store" 
                  className="h-7 w-auto object-contain" 
                />
              </a>
              <a 
                href="#" 
                className="flex items-center justify-center px-6 py-2.5 rounded-full bg-[#030712] hover:bg-black text-white border border-white/10 transition-all shadow-lg active:scale-95"
              >
                <img 
                  src="https://upload.wikimedia.org/wikipedia/commons/7/78/Google_Play_Store_badge_EN.svg" 
                  alt="Google Play" 
                  className="h-7 w-auto object-contain" 
                />
              </a>
            </div>
          </div>

          {/* Right Phone Mockup Image */}
          <div className="flex justify-center relative w-full lg:w-auto lg:self-end -mb-8 sm:-mb-10 lg:-mb-8 mt-6 lg:mt-0">
            <img 
              src="/cta_mockup.png" 
              alt="MedScan App Dashboard" 
              className="h-[360px] sm:h-[420px] lg:h-[480px] w-auto object-contain drop-shadow-2xl hover:scale-102 transition-transform duration-500"
            />
          </div>

        </div>
      </section>

      {/* 10. FOOTER */}
      <footer className="bg-white dark:bg-slate-950 border-t border-slate-200/50 dark:border-slate-800/50 py-16 px-6 relative z-10">
        <div className="max-w-7xl mx-auto grid grid-cols-1 md:grid-cols-12 gap-12">
          
          {/* Logo & Description */}
          <div className="md:col-span-4 flex flex-col space-y-6">
            <div className="flex items-center space-x-2">
              <img 
                src="/logo.png" 
                alt="Medscan Logo" 
                className="h-9 w-auto object-contain"
              />
              <span className="text-xl sm:text-2xl font-black tracking-tight text-slate-900 dark:text-white font-sans">
                Medscan.
              </span>
            </div>
            <p className="text-xs text-slate-500 dark:text-slate-400 leading-relaxed font-medium">
              MedScan est un outil informatif intelligent facilitant l'accès à l'information pharmaceutique grâce à la vision par ordinateur et à l'intelligence artificielle.
            </p>
            <div className="text-xs text-slate-400 font-semibold">
              © 2026 MedScan Inc. Tous droits réservés.
            </div>
          </div>

          {/* Spacer */}
          <div className="hidden md:block md:col-span-4"></div>

          {/* Links 1 */}
          <div className="md:col-span-2 flex flex-col space-y-4">
            <h5 className="text-xs font-extrabold text-slate-800 dark:text-slate-200 uppercase tracking-widest">Navigation</h5>
            <a href="#features" className="text-xs text-slate-500 dark:text-slate-400 hover:text-blue-600 transition-colors">Fonctionnalités</a>
            <a href="#how-it-works" className="text-xs text-slate-500 dark:text-slate-400 hover:text-blue-600 transition-colors">Démo Interactive</a>
            <a href="#testimonials" className="text-xs text-slate-500 dark:text-slate-400 hover:text-blue-600 transition-colors">Avis</a>
            <a href="#faq" className="text-xs text-slate-500 dark:text-slate-400 hover:text-blue-600 transition-colors">FAQ</a>
          </div>

          {/* Links 3 */}
          <div className="md:col-span-2 flex flex-col space-y-4">
            <h5 className="text-xs font-extrabold text-slate-800 dark:text-slate-200 uppercase tracking-widest">Informations</h5>
            <a href="#" className="text-xs text-slate-500 dark:text-slate-400 hover:text-blue-600 transition-colors">Politique de Confidentialité</a>
            <a href="#" className="text-xs text-slate-500 dark:text-slate-400 hover:text-blue-600 transition-colors">Conditions d'Utilisation</a>
            <a href="#" className="text-xs text-slate-500 dark:text-slate-400 hover:text-blue-600 transition-colors">Avis Médical de non-responsabilité</a>
          </div>

        </div>
      </footer>

    </div>
  );
}

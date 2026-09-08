import WidgetKit
import SwiftUI
import AppIntents
import home_widget

// MARK: - Localization Helper
struct WidgetStrings {
    let greeting: (Int) -> String
    let nextReminder: String
    let healthTracking: String
    let noReminder: String
    let takeCareSub: String
    let taken: String
    let done: String
    let progressLabel: String
    let readyScans: String

    static func forLang(_ code: String) -> WidgetStrings {
        switch code {
        case "en":
            return WidgetStrings(
                greeting: { hour in
                    if hour >= 5 && hour < 12 { return "Good morning" }
                    if hour >= 12 && hour < 18 { return "Good afternoon" }
                    return "Good evening"
                },
                nextReminder: "NEXT REMINDER",
                healthTracking: "HEALTH TRACKING",
                noReminder: "No active reminder",
                takeCareSub: "Take care of yourself ✨",
                taken: "Taken",
                done: "Done ✓",
                progressLabel: "Progress to dose",
                readyScans: "Ready for your scans"
            )
        case "ar":
            return WidgetStrings(
                greeting: { hour in
                    if hour >= 5 && hour < 12 { return "صباح الخير" }
                    if hour >= 12 && hour < 18 { return "مساء الخير" }
                    return "مساء الخير"
                },
                nextReminder: "التذكير التالي",
                healthTracking: "متابعة صحية",
                noReminder: "لا تذكير نشط",
                takeCareSub: "اعتنِ بنفسك ✨",
                taken: "تم",
                done: "تم ✓",
                progressLabel: "التقدم نحو الجrعة",
                readyScans: "جاهز للمسح"
            )
        case "tr":
            return WidgetStrings(
                greeting: { hour in
                    if hour >= 5 && hour < 12 { return "Günaydın" }
                    if hour >= 12 && hour < 18 { return "İyi öğleden sonralar" }
                    return "İyi akşamlar"
                },
                nextReminder: "SONRAKİ HATIRLATMA",
                healthTracking: "SAĞLIK TAKİBİ",
                noReminder: "Aktif hatırlatma yok",
                takeCareSub: "Kendinize iyi bakın ✨",
                taken: "Alındı",
                done: "Tamam ✓",
                progressLabel: "Doza doğru ilerleme",
                readyScans: "Taramalarınız için hazır"
            )
        default: // "fr"
            return WidgetStrings(
                greeting: { hour in
                    if hour >= 5 && hour < 12 { return "Bonjour" }
                    if hour >= 12 && hour < 18 { return "Bon après-midi" }
                    return "Bonsoir"
                },
                nextReminder: "PROCHAIN RAPPEL",
                healthTracking: "SUIVI SANTÉ",
                noReminder: "Aucun rappel actif",
                takeCareSub: "Prenez soin de vous ✨",
                taken: "Pris",
                done: "Fait ✓",
                progressLabel: "Progression vers la dose",
                readyScans: "Prêt pour vos scans"
            )
        }
    }
}

// MARK: - AppIntent for "Taken" Button (iOS 17+)
@available(iOS 17.0, *)
struct MarkMedicationTakenIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Medication Taken"
    static var description: IntentDescription = IntentDescription("Mark the current medication reminder as taken")

    @Parameter(title: "url")
    var url: URL?

    init() {}
    
    init(url: URL?) {
        self.url = url
    }

    func perform() async throws -> some IntentResult {
        let ud = UserDefaults(suiteName: "group.com.seinimomo.medscanapp")
        ud?.set(true, forKey: "medication_taken")
        ud?.set(Date().timeIntervalSince1970, forKey: "medication_taken_at")
        let currentId = ud?.string(forKey: "reminder_id") ?? ""
        ud?.set(currentId, forKey: "medication_taken_id")
        
        // Optimistically update the UI state as well
        let total = max(1, ud?.integer(forKey: "total_doses") ?? 1)
        let taken = ud?.integer(forKey: "taken_doses") ?? 0
        let newTaken = min(taken + 1, total)
        ud?.set(newTaken, forKey: "taken_doses")
        let prog = Double(newTaken) / Double(total)
        ud?.set(prog, forKey: "progress")
        if newTaken >= total {
            ud?.set(true, forKey: "all_done")
        }
        ud?.synchronize()
        
        // Optimistic update instantly
        WidgetCenter.shared.reloadAllTimelines()
        
        // Trigger Flutter background callback asynchronously so UI updates instantly
        Task {
            if let url = url {
                await HomeWidgetBackgroundWorker.run(url: url, appGroup: "group.com.seinimomo.medscanapp")
            } else {
                let fallbackUrl = URL(string: "medscan://mark_taken")
                await HomeWidgetBackgroundWorker.run(url: fallbackUrl, appGroup: "group.com.seinimomo.medscanapp")
            }
        }
        
        return .result()
    }
}

// MARK: - Data Provider
struct MedScanProvider: TimelineProvider {
    func placeholder(in context: Context) -> MedScanEntry {
        MedScanEntry(
            date: Date(),
            greeting: "Bonjour 🌤️",
            userName: "",
            avatarId: "Avatar1",
            reminderName: "Aucun rappel actif",
            reminderTime: "--:--",
            reminderDosage: "Prenez soin de vous ✨",
            reminderProgress: 0.0,
            hasReminder: false,
            isTaken: false,
            langCode: "fr",
            progress: 0.0,
            streak: 0,
            allDone: false,
            totalDoses: 1,
            takenDoses: 0,
            isPending: false,
            targetDate: nil,
            weekHistory: "0000000",
            hasReminders: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MedScanEntry) -> ()) {
        completion(getEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MedScanEntry>) -> ()) {
        let entry = getEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func computeProgress(timeStr: String) -> Double {
        let parts = timeStr.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return 0.5 }
        let now = Calendar.current
        let nowMin = now.component(.hour, from: Date()) * 60 + now.component(.minute, from: Date())
        let targetMin = parts[0] * 60 + parts[1]
        var diff = targetMin - nowMin
        if diff < 0 { diff += 24 * 60 }
        return max(0.05, 1.0 - min(Double(diff) / Double(12 * 60), 1.0))
    }

    private func getEntry() -> MedScanEntry {
        let ud = UserDefaults(suiteName: "group.com.seinimomo.medscanapp")
        let name     = ud?.string(forKey: "reminder_name") ?? ""
        let time     = ud?.string(forKey: "reminder_time") ?? ""
        let dose     = ud?.string(forKey: "reminder_dosage") ?? ""
        let user     = ud?.string(forKey: "user_name") ?? ""
        let avatar   = ud?.string(forKey: "avatar_id") ?? "Avatar1"
        let lang     = ud?.string(forKey: "lang_code") ?? "fr"
        let taken    = ud?.bool(forKey: "medication_taken") ?? false
        
        let progress = ud?.double(forKey: "progress") ?? 0.0
        let allDone  = ud?.bool(forKey: "all_done") ?? false
        let streak   = ud?.integer(forKey: "streak") ?? 0
        let totalDoses = ud?.integer(forKey: "total_doses") ?? 1
        let takenDoses = ud?.integer(forKey: "taken_doses") ?? 0
        
        let isPending = ud?.bool(forKey: "is_pending") ?? false
        let nextDoseTimestamp = ud?.integer(forKey: "next_dose_timestamp") ?? 0
        let targetDate = nextDoseTimestamp > 0 ? Date(timeIntervalSince1970: TimeInterval(nextDoseTimestamp) / 1000.0) : nil
        let weekHistory = ud?.string(forKey: "week_history") ?? "0000000"
        let hasReminders = ud?.object(forKey: "has_reminders") != nil ? (ud?.bool(forKey: "has_reminders") ?? true) : true
        
        // Ensure totalDoses is at least 1 to avoid division by zero later
        let safeTotalDoses = max(1, totalDoses)
        
        let has      = !name.isEmpty && name != "Aucun rappel" && !allDone

        let strings = WidgetStrings.forLang(lang)
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting = strings.greeting(hour)

        return MedScanEntry(
            date: Date(),
            greeting: greeting,
            userName: user,
            avatarId: avatar.isEmpty ? "Avatar1" : avatar,
            reminderName: allDone ? "Tout est pris ! 🎉" : (has ? name : strings.noReminder),
            reminderTime: allDone ? "" : (has ? time : "--:--"),
            reminderDosage: allDone ? "Excellente journée" : (has ? dose : strings.takeCareSub),
            reminderProgress: has ? computeProgress(timeStr: time) : 0.0,
            hasReminder: has,
            isTaken: taken && has,
            langCode: lang,
            progress: progress,
            streak: streak,
            allDone: allDone,
            totalDoses: safeTotalDoses,
            takenDoses: takenDoses,
            isPending: isPending,
            targetDate: targetDate,
            weekHistory: weekHistory,
            hasReminders: hasReminders
        )
    }
}

// MARK: - Entry Model
struct MedScanEntry: TimelineEntry {
    let date: Date
    let greeting: String
    let userName: String
    let avatarId: String
    let reminderName: String
    let reminderTime: String
    let reminderDosage: String
    let reminderProgress: Double
    let hasReminder: Bool
    let isTaken: Bool
    let langCode: String
    
    // New fields
    let progress: Double // overall daily progress 0.0 to 1.0
    let streak: Int
    let allDone: Bool
    let totalDoses: Int
    let takenDoses: Int
    let isPending: Bool
    let targetDate: Date?
    let weekHistory: String
    let hasReminders: Bool
}

// MARK: - Pure Sky-Blue Cloud Glassmorphic Background
struct GlassmorphicBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.72, green: 0.86, blue: 0.98),
                    Color(red: 0.54, green: 0.75, blue: 0.96),
                    Color(red: 0.40, green: 0.65, blue: 0.93)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.38),
                    Color.white.opacity(0.08),
                    Color.white.opacity(0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Widget Content View
struct MedScanWidgetEntryView: View {
    var entry: MedScanProvider.Entry
    @Environment(\.widgetFamily) var family

    let deepNavy   = Color(red: 0.08, green: 0.20, blue: 0.35)
    let brandBlue  = Color(red: 0.15, green: 0.45, blue: 0.85)
    let textMuted  = Color(red: 0.25, green: 0.38, blue: 0.52)
    let cyanElectric = Color(red: 0.00, green: 0.96, blue: 0.83)
    let takenGreen = Color(red: 0.18, green: 0.75, blue: 0.45)

    private var strings: WidgetStrings {
        WidgetStrings.forLang(entry.langCode)
    }

    var body: some View {
        Group {
            if #available(iOS 16.0, *), family == .accessoryCircular {
                LockScreenWidgetCircular(entry: entry)
            } else if #available(iOS 16.0, *), family == .accessoryRectangular {
                LockScreenWidgetRectangular(entry: entry)
            } else {
                switch family {
                case .systemSmall:
                    SmallWidgetView(entry: entry, strings: strings, deepNavy: deepNavy, brandBlue: brandBlue, textMuted: textMuted, cyanElectric: cyanElectric, takenGreen: takenGreen)
                case .systemMedium:
                    MediumWidgetView(entry: entry, strings: strings, deepNavy: deepNavy, brandBlue: brandBlue, textMuted: textMuted, cyanElectric: cyanElectric, takenGreen: takenGreen)
                case .systemLarge:
                    LargeWidgetView(entry: entry, strings: strings, deepNavy: deepNavy, brandBlue: brandBlue, textMuted: textMuted, cyanElectric: cyanElectric, takenGreen: takenGreen)
                default:
                    MediumWidgetView(entry: entry, strings: strings, deepNavy: deepNavy, brandBlue: brandBlue, textMuted: textMuted, cyanElectric: cyanElectric, takenGreen: takenGreen)
                }
            }
        }
        .unredacted()
        .widgetURL(URL(string: "medscan://home"))
        .containerBackground(for: .widget) {
            if #available(iOS 16.0, *), family == .accessoryCircular || family == .accessoryRectangular {
                Color.clear
            } else {
                GlassmorphicBackground()
            }
        }
    }
}

// MARK: - Lock Screen Widgets
@available(iOS 16.0, *)
struct LockScreenWidgetCircular: View {
    let entry: MedScanEntry
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Circle()
                .trim(from: 0, to: entry.progress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(4)
            if entry.allDone {
                Image(systemName: "checkmark")
            } else {
                Text("\(entry.takenDoses)/\(entry.totalDoses)")
                    .font(.system(size: 14, weight: .bold))
            }
        }
    }
}

@available(iOS 16.0, *)
struct LockScreenWidgetRectangular: View {
    let entry: MedScanEntry
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Logo on the left
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                // Name
                Text(entry.reminderName)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                
                // Timer and Status on the same line
                HStack(alignment: .firstTextBaseline) {
                    if entry.isPending, let target = entry.targetDate {
                        Text(timerInterval: Date()...target)
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    } else if !entry.allDone && entry.hasReminder {
                        Text(entry.reminderTime)
                            .font(.system(size: 12, weight: .medium))
                    }
                    
                    Spacer()
                    
                    if entry.hasReminder && !entry.allDone {
                        if entry.isPending {
                            Text("EN ATTENTE")
                                .font(.system(size: 9, weight: .bold))
                                .opacity(0.8)
                        } else {
                            if #available(iOS 17.0, *) {
                                Button(intent: MarkMedicationTakenIntent()) {
                                    Text("PRIS ✓")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text("À PRENDRE")
                                    .font(.system(size: 9, weight: .bold))
                            }
                        }
                    } else if entry.allDone {
                        HStack(spacing: 2) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 8))
                                .foregroundColor(.orange)
                            Text("Terminé")
                                .font(.system(size: 9, weight: .bold))
                        }
                    }
                }
                
                // Simple Progress Bar
                GeometryReader { geo in
                    let safeTotal = max(1, entry.totalDoses)
                    let progress = CGFloat(min(entry.takenDoses, safeTotal)) / CGFloat(safeTotal)
                    
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.3))
                        Capsule().fill(Color.white)
                            .frame(width: max(0, geo.size.width * progress))
                    }
                }
                .frame(height: 5)
            }
        }
    }
}

// MARK: - Premium Node Progress Bar
struct PremiumNodeProgressBar: View {
    var totalDoses: Int
    var takenDoses: Int
    var brandBlue: Color
    var takenGreen: Color
    
    var body: some View {
        let safeTotal = max(1, totalDoses)
        let safeTaken = min(takenDoses, safeTotal)
        let progress = CGFloat(safeTaken) / CGFloat(safeTotal)
        let isDone = safeTaken >= safeTotal
        
        let activeColors: [Color] = isDone ? [takenGreen.opacity(0.7), takenGreen] : [brandBlue.opacity(0.7), brandBlue]
        
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Glassmorphism Background Track
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(height: 14)
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
                
                // Animated Gradient Fill
                Capsule()
                    .fill(LinearGradient(colors: activeColors, startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(14, geo.size.width * progress), height: 14)
                    .shadow(color: activeColors.last!.opacity(0.8), radius: 6, x: 0, y: 0)
                
                // Nodes distributed evenly
                HStack(spacing: 0) {
                    ForEach(0..<safeTotal, id: \.self) { i in
                        let isPassed = i < safeTaken
                        let isActiveNode = i == safeTaken
                        
                        ZStack {
                            Circle()
                                .fill(isPassed ? activeColors.last! : Color.white.opacity(0.9))
                                .frame(width: isPassed ? 18 : 12, height: isPassed ? 18 : 12)
                                .shadow(color: isPassed ? activeColors.last!.opacity(0.6) : .clear, radius: 4)
                                .overlay(
                                    Circle().stroke(Color.white, lineWidth: isPassed ? 2 : 1)
                                )
                            
                            if isPassed {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .scaleEffect(isPassed ? 1.0 : 0.0)
                            }
                        }
                        .scaleEffect(isActiveNode && !isDone ? 1.2 : 1.0)
                        
                        if i < (safeTotal - 1) {
                            Spacer()
                        }
                    }
                }
            }
            .frame(height: 24)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.6, blendDuration: 0), value: safeTaken)
        .animation(.spring(response: 0.6, dampingFraction: 0.6, blendDuration: 0), value: progress)
    }
}



// MARK: - Subviews for different sizes
struct SmallWidgetView: View {
    let entry: MedScanEntry
    let strings: WidgetStrings
    let deepNavy: Color
    let brandBlue: Color
    let textMuted: Color
    let cyanElectric: Color
    let takenGreen: Color

    var body: some View {
        if entry.hasReminders {
            VStack(spacing: 8) {
                // New Fluid Progress Bar
                PremiumNodeProgressBar(
                    totalDoses: entry.totalDoses,
                    takenDoses: entry.takenDoses,
                    brandBlue: brandBlue,
                    takenGreen: takenGreen
                )
                .frame(height: 80)
                
                if entry.allDone {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                } else {
                    Text("\(Int(entry.progress * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(deepNavy)
                }
                
                Text(entry.allDone ? "Journée terminée" : "Médicaments du jour")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(deepNavy)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        } else {
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(entry.avatarId.isEmpty ? "Avatar1" : entry.avatarId)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 22, height: 22)
                        .clipShape(Circle())
                    Text(entry.userName.isEmpty ? "Utilisateur" : entry.userName)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(deepNavy)
                }
                
                Link(destination: URL(string: "medscan://scan")!) {
                    VStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                        Text("Scanner")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(brandBlue))
                }
            }
            .padding(12)
        }
    }
}

struct MediumWidgetView: View {
    let entry: MedScanEntry
    let strings: WidgetStrings
    let deepNavy: Color
    let brandBlue: Color
    let textMuted: Color
    let cyanElectric: Color
    let takenGreen: Color

    var body: some View {
        VStack(spacing: 0) {
            // Header (similar to original layout)
            HStack(alignment: .center, spacing: 10) {
                Image(entry.avatarId.isEmpty ? "Avatar1" : entry.avatarId)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 1.5))
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(entry.greeting)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(deepNavy.opacity(0.75))
                        
                        let hour = Calendar.current.component(.hour, from: Date())
                        let isDaytime = hour >= 5 && hour < 18
                        Image(systemName: isDaytime ? "sun.max.fill" : "moon.stars.fill")
                            .font(.system(size: 10))
                            .foregroundColor(isDaytime ? .orange : brandBlue)
                    }
                    Text(entry.userName.isEmpty ? "Utilisateur" : entry.userName)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(deepNavy)
                }
                
                Spacer(minLength: 4)
                
                if entry.streak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text("\(entry.streak) j")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(deepNavy)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.6)))
                }
                
                Link(destination: URL(string: "medscan://scan")!) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Circle().fill(brandBlue))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            
            Spacer()
            
            // Body
            if entry.hasReminders {
                VStack(alignment: .leading, spacing: 2) {
                    
                    Text(entry.hasReminder ? strings.nextReminder : (entry.allDone ? "SUIVI" : strings.healthTracking))
                        .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                        .foregroundColor(brandBlue)
                    
                    HStack(alignment: .center, spacing: 6) {
                        Text(entry.reminderName)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(deepNavy)
                        
                        if entry.isPending, let target = entry.targetDate {
                            Text(timerInterval: Date()...target)
                                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                .foregroundColor(brandBlue)
                        }
                    }
                    
                    Text(entry.reminderDosage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(textMuted)
                    
                    if entry.hasReminder && !entry.allDone {
                        HStack(spacing: 5) {
                            if entry.isPending {
                                HStack(spacing: 4) {
                                    Text("EN ATTENTE").font(.system(size: 10, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(textMuted.opacity(0.8))
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .background(Capsule().fill(Color.white.opacity(0.4)))
                            } else {
                                HStack(spacing: 3) {
                                    Image(systemName: "clock.fill").font(.system(size: 9))
                                    Text(entry.reminderTime).font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                }
                                .foregroundColor(deepNavy)
                                .padding(.horizontal, 6).padding(.vertical, 4)
                                .background(Capsule().fill(Color.white.opacity(0.50)))
                                
                                if #available(iOS 17.0, *) {
                                    Button(intent: MarkMedicationTakenIntent()) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                                            Text(strings.taken).font(.system(size: 11, weight: .bold, design: .rounded))
                                        }
                                        .foregroundColor(brandBlue)
                                        .padding(.horizontal, 10).padding(.vertical, 8)
                                        .background(Capsule().fill(Color.white.opacity(0.9)))
                                        .contentShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                    
                    Spacer(minLength: 4)
                    
                    PremiumNodeProgressBar(
                        totalDoses: entry.totalDoses,
                        takenDoses: entry.takenDoses,
                        brandBlue: brandBlue,
                        takenGreen: takenGreen
                    )
                    .frame(height: 24)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            } else {
                VStack(alignment: .center, spacing: 6) {
                    Text("Aucun traitement programmé")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(deepNavy.opacity(0.8))
                        .padding(.top, 4)
                    
                    HStack(spacing: 8) {
                        // Button: Scanner
                        Link(destination: URL(string: "medscan://scan")!) {
                            VStack(spacing: 6) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(deepNavy)
                                Text("Scanner")
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                    .foregroundColor(deepNavy)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.4)))
                        }
                        
                        // Button: Ajouter
                        Link(destination: URL(string: "medscan://home")!) {
                            VStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18))
                                    .foregroundColor(deepNavy)
                                Text("Ajouter")
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                    .foregroundColor(deepNavy)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.4)))
                        }
                        
                        // Button: Pharmacie
                        Link(destination: URL(string: "medscan://pharmacy")!) {
                            VStack(spacing: 6) {
                                Image(systemName: "pills.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(deepNavy)
                                Text("Pharmacie")
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                    .foregroundColor(deepNavy)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.4)))
                        }
                    }
                    .frame(height: 60)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
    }
}

struct LargeWidgetView: View {
    let entry: MedScanEntry
    let strings: WidgetStrings
    let deepNavy: Color
    let brandBlue: Color
    let textMuted: Color
    let cyanElectric: Color
    let takenGreen: Color

    private func isDayTaken(_ index: Int) -> Bool {
        guard index < entry.weekHistory.count else { return false }
        let charIndex = entry.weekHistory.index(entry.weekHistory.startIndex, offsetBy: index)
        return entry.weekHistory[charIndex] == "1"
    }

    var body: some View {
        if entry.hasReminders {
            VStack(spacing: 0) {
                // Header (with top padding to push it down slightly, as requested)
                HStack(alignment: .center, spacing: 10) {
                    Image(entry.avatarId.isEmpty ? "Avatar1" : entry.avatarId)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 1.5))
                    
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(entry.greeting)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(deepNavy.opacity(0.75))
                            
                            let hour = Calendar.current.component(.hour, from: Date())
                            let isDaytime = hour >= 5 && hour < 18
                            Image(systemName: isDaytime ? "sun.max.fill" : "moon.stars.fill")
                                .font(.system(size: 10))
                                .foregroundColor(isDaytime ? .orange : brandBlue)
                        }
                        Text(entry.userName.isEmpty ? "Utilisateur" : entry.userName)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(deepNavy)
                    }
                    
                    Spacer(minLength: 4)
                    
                    if entry.streak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            Text("\(entry.streak) j")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(deepNavy)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.6)))
                    }
                    
                    Link(destination: URL(string: "medscan://scan")!) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Circle().fill(brandBlue))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 24)
                
                Spacer()
                
                // Centered Medication Details
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.hasReminder ? strings.nextReminder : (entry.allDone ? "SUIVI" : strings.healthTracking))
                        .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                        .foregroundColor(brandBlue)
                    
                    HStack(alignment: .center, spacing: 6) {
                        Text(entry.reminderName)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(deepNavy)
                        
                        if entry.isPending, let target = entry.targetDate {
                            Text(timerInterval: Date()...target)
                                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                .foregroundColor(brandBlue)
                        }
                    }
                    
                    Text(entry.reminderDosage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(textMuted)
                    
                    if entry.hasReminder && !entry.allDone {
                        HStack(spacing: 5) {
                            if entry.isPending {
                                HStack(spacing: 4) {
                                    Text("EN ATTENTE").font(.system(size: 10, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(textMuted.opacity(0.8))
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .background(Capsule().fill(Color.white.opacity(0.4)))
                            } else {
                                HStack(spacing: 3) {
                                    Image(systemName: "clock.fill").font(.system(size: 9))
                                    Text(entry.reminderTime).font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                }
                                .foregroundColor(deepNavy)
                                .padding(.horizontal, 6).padding(.vertical, 4)
                                .background(Capsule().fill(Color.white.opacity(0.50)))
                                
                                if #available(iOS 17.0, *) {
                                    Button(intent: MarkMedicationTakenIntent()) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                                            Text(strings.taken).font(.system(size: 11, weight: .bold, design: .rounded))
                                        }
                                        .foregroundColor(brandBlue)
                                        .padding(.horizontal, 10).padding(.vertical, 8)
                                        .background(Capsule().fill(Color.white.opacity(0.9)))
                                        .contentShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 14)
                
                Spacer()
                
                // Progress Bar
                PremiumNodeProgressBar(
                    totalDoses: entry.totalDoses,
                    takenDoses: entry.takenDoses,
                    brandBlue: brandBlue,
                    takenGreen: takenGreen
                )
                .frame(height: 24)
                .padding(.horizontal, 14)
                
                Spacer()
                
                Divider().background(Color.white.opacity(0.5))
                
                Spacer()
                
                // Weekly compliance dots (centered)
                VStack(alignment: .center, spacing: 6) {
                    Text("VOTRE SEMAINE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(deepNavy.opacity(0.7))
                    
                    HStack(spacing: 12) {
                        ForEach(0..<7) { i in
                            VStack(spacing: 4) {
                                Text(["L", "M", "M", "J", "V", "S", "D"][i])
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(deepNavy.opacity(0.8))
                                Circle()
                                    .fill(isDayTaken(i) ? takenGreen : Color.white.opacity(0.4))
                                    .frame(width: 14, height: 14)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 14)
            }
        } else {
            VStack(spacing: 0) {
                // Header (same as MediumWidgetView header)
                HStack(alignment: .center, spacing: 10) {
                    Image(entry.avatarId.isEmpty ? "Avatar1" : entry.avatarId)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 1.5))
                    
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(entry.greeting)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(deepNavy.opacity(0.75))
                            
                            let hour = Calendar.current.component(.hour, from: Date())
                            let isDaytime = hour >= 5 && hour < 18
                            Image(systemName: isDaytime ? "sun.max.fill" : "moon.stars.fill")
                                .font(.system(size: 10))
                                .foregroundColor(isDaytime ? .orange : brandBlue)
                        }
                        Text(entry.userName.isEmpty ? "Utilisateur" : entry.userName)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(deepNavy)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)
                
                Spacer()
                
                // Centered Empty State Buttons
                VStack(spacing: 12) {
                    Text("Aucun traitement programmé")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(deepNavy.opacity(0.8))
                        .padding(.bottom, 6)
                    
                    HStack(spacing: 10) {
                        // Button: Scanner
                        Link(destination: URL(string: "medscan://scan")!) {
                            VStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(deepNavy)
                                Text("Scanner")
                                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                    .foregroundColor(deepNavy)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.4)))
                        }
                        
                        // Button: Ajouter
                        Link(destination: URL(string: "medscan://home")!) {
                            VStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 20))
                                    .foregroundColor(deepNavy)
                                Text("Ajouter")
                                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                    .foregroundColor(deepNavy)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.4)))
                        }
                        
                        // Button: Pharmacie
                        Link(destination: URL(string: "medscan://pharmacy")!) {
                            VStack(spacing: 8) {
                                Image(systemName: "pills.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(deepNavy)
                                Text("Pharmacie")
                                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                    .foregroundColor(deepNavy)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.4)))
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .padding(.horizontal, 14)
                
                Spacer()
                Spacer()
            }
        }
    }
}

// MARK: - Widget Configuration
struct MedScanWidget: Widget {
    let kind: String = "MedScanWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MedScanProvider()) { entry in
            MedScanWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MedScan")
        .description("Vos rappels et suivi santé.")
#if os(iOS)
        .supportedFamilies({
            if #available(iOS 16.0, *) {
                return [.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular]
            } else {
                return [.systemSmall, .systemMedium, .systemLarge]
            }
        }())
#else
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
#endif
        .contentMarginsDisabled()
    }
}

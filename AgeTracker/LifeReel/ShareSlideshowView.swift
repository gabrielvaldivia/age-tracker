//
//  ShareSlideshowView.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 8/9/24.
//

import Foundation
import SwiftUI
import AVKit
import Photos

enum SlideshowRange: Hashable, CaseIterable {
    case allPhotos
    case pregnancy
    case birthMonth
    case month(Int)
    case year(Int)
    case custom(String)

    var displayName: String {
        switch self {
        case .allPhotos:
            return "All Photos"
        case .pregnancy:
            return "Pregnancy"
        case .birthMonth:
            return "Birth Month"
        case .month(let value):
            return "\(value) Month\(value == 1 ? "" : "s")"
        case .year(let value):
            return "\(value) Year\(value == 1 ? "" : "s")"
        case .custom(let value):
            return value
        }
    }
    
    static var allCases: [SlideshowRange] {
        var cases: [SlideshowRange] = [.allPhotos, .pregnancy, .birthMonth]
        for month in 1...12 {
            cases.append(.month(month))
        }
        for year in 1...18 {
            cases.append(.year(year))
        }
        return cases
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .allPhotos:
            hasher.combine(0)
        case .pregnancy:
            hasher.combine(1)
        case .birthMonth:
            hasher.combine(2)
        case .month(let value):
            hasher.combine(3)
            hasher.combine(value)
        case .year(let value):
            hasher.combine(4)
            hasher.combine(value)
        case .custom(let value):
            hasher.combine(5)
            hasher.combine(value)
        }
    }

    static func == (lhs: SlideshowRange, rhs: SlideshowRange) -> Bool {
        switch (lhs, rhs) {
        case (.allPhotos, .allPhotos),
             (.pregnancy, .pregnancy),
             (.birthMonth, .birthMonth):
            return true
        case let (.month(lhsValue), .month(rhsValue)):
            return lhsValue == rhsValue
        case let (.year(lhsValue), .year(rhsValue)):
            return lhsValue == rhsValue
        case let (.custom(lhsValue), .custom(rhsValue)):
            return lhsValue == rhsValue
        default:
            return false
        }
    }
}

// ShareSlideshowView
struct ShareSlideshowView: View {
    // Properties
    let photos: [Photo]
    let person: Person
    let sectionTitle: String?
    @State private var currentPhotoIndex = 0
    @State private var isPlaying = false
    @State private var playbackSpeed: Double = 1.0
    @State private var isSharePresented = false
    @State private var showComingSoonAlert = false
    @State private var loadedImages: [String: UIImage] = [:]
    @State private var timer: Timer?
    @State private var scrubberPosition: Double = 0
    @Environment(\.presentationMode) var presentationMode
    
    @State private var currentFilteredPhotoIndex = 0
    @State private var aspectRatio: AspectRatio = .square
    @State private var isMusicSelectionPresented = false
    @State private var showAppIcon: Bool = true
    @State private var titleOption: TitleOption = .name
    @State private var subtitleOption: TitleOption = .age
    @State private var speedOptions = [1.0, 2.0, 3.0]
    
    init(photos: [Photo], person: Person, sectionTitle: String? = nil) {
        self.photos = photos
        self.person = person
        self.sectionTitle = sectionTitle
        
        // Subtitle option always defaults to age
        _subtitleOption = State(initialValue: .age)
    }
    
    enum TitleOption: String, CaseIterable, CustomStringConvertible {
        case none = "None"
        case name = "Name"
        case age = "Age"
        case date = "Date"
        case stackName = "Stack Name"
        
        var description: String { self.rawValue }
    }
    
    // Body
    var body: some View {   
        VStack(alignment: .center, spacing: 10) {
            navigationBar
            
            if filteredPhotos.isEmpty {
                emptyStateView
            } else {
                photoView
                playbackControls
                bottomControls
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(UIColor.secondarySystemBackground))
        .onAppear(perform: onAppear)
        .onChange(of: isPlaying) { oldValue, newValue in
            handlePlayingChange(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: playbackSpeed) { oldValue, newValue in
            handleSpeedChange(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: currentFilteredPhotoIndex) { oldValue, newValue in
            handleIndexChange(oldValue: oldValue, newValue: newValue)
        }
        .alert("Coming Soon", isPresented: $showComingSoonAlert, actions: comingSoonAlert)
        .sheet(isPresented: $isMusicSelectionPresented) {
            MusicSelectionView()
        }
    }
    
    private var navigationBar: some View {
        HStack {
            cancelButton
            Spacer()
            Text("Slideshow")
                .font(.headline)
            Spacer()
            shareButton
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }

    private var emptyStateView: some View {
        Text("No photos available for this range")
            .foregroundColor(.secondary)
            .padding()
    }

    private var photoView: some View {
        VStack {
            Spacer()
            if !photos.isEmpty {
                let safeIndex = min(currentFilteredPhotoIndex, filteredPhotos.count - 1)
                if safeIndex >= 0 && safeIndex < filteredPhotos.count {
                    LazyImage(
                        photo: filteredPhotos[safeIndex],
                        loadedImage: loadedImages[filteredPhotos[safeIndex].id.uuidString] ?? UIImage(),
                        aspectRatio: aspectRatio.value,
                        showAppIcon: showAppIcon,
                        titleText: getTitleText(for: filteredPhotos[safeIndex]),
                        subtitleText: getSubtitleText(for: filteredPhotos[safeIndex])
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                } else {
                    Text("No photos available")
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No photos available")
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var playbackControls: some View {
        Group {
            if filteredPhotos.count > 1 {
                HStack(spacing: 20) {
                    PlayButton(isPlaying: $isPlaying)
                        .frame(width: 40, height: 40)
                    
                    Slider(value: $scrubberPosition, in: 0...Double(filteredPhotos.count - 1), step: 1)
                        .onChange(of: scrubberPosition) { oldValue, newValue in
                            if !isPlaying {
                                currentFilteredPhotoIndex = Int(newValue.rounded())
                                loadImagesAround(index: currentFilteredPhotoIndex)
                            }
                        }
                }
                .padding(.leading, 20)
                .padding(.trailing, 40)
            }
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 20) {
            Divider()
            
            HStack(spacing: 20) {
                SimplifiedCustomizationButton(
                    icon: "textformat",
                    title: "Title",
                    options: TitleOption.allCases,
                    selection: $titleOption
                )
                
                SimplifiedCustomizationButton(
                    icon: "text.alignleft",
                    title: "Subtitle",
                    options: availableSubtitleOptions,
                    selection: $subtitleOption
                )
                
                SimplifiedCustomizationButton(
                    icon: "aspectratio",
                    title: "Aspect Ratio",
                    options: [AspectRatio.square, AspectRatio.portrait],
                    selection: $aspectRatio
                )
                
                SimplifiedCustomizationButton(
                    icon: "speedometer",
                    title: "Speed",
                    options: speedOptions.map { "\(Int($0))x" },
                    selection: Binding(
                        get: { "\(Int(self.playbackSpeed))x" },
                        set: { newValue in
                            if let speed = Double(newValue.dropLast()) {
                                self.playbackSpeed = speed
                            }
                        }
                    )
                )
                
                Button(action: { showAppIcon.toggle() }) {
                    VStack(spacing: 8) {
                        Image(systemName: showAppIcon ? "app.badge.checkmark" : "app")
                            .font(.system(size: 24))
                            .frame(height: 24)
                        Text("App Icon")
                            .font(.caption)
                    }
                    .frame(width: 70)
                }
                .foregroundColor(.primary)
            }
            .padding(.horizontal, 10)
        }
        .padding(.vertical, 10)
        .frame(height: 80)
        .background(Color(UIColor.secondarySystemBackground))
    }

    private func onAppear() {
        loadImagesAround(index: currentFilteredPhotoIndex)
    }

    private func handlePlayingChange(oldValue: Bool, newValue: Bool) {
        if newValue {
            startTimer()
        } else {
            stopTimer()
        }
    }

    private func handleSpeedChange(oldValue: Double, newValue: Double) {
        if isPlaying {
            stopTimer()
            startTimer()
        }
    }

    private func handleIndexChange(oldValue: Int, newValue: Int) {
        if !isPlaying {
            scrubberPosition = Double(newValue)
        }
    }

    private func comingSoonAlert() -> some View {
        Button("OK", role: .cancel) { }
    }

    // Helper Methods
    private func loadImagesAround(index: Int) {
        let photos = filteredPhotos
        guard !photos.isEmpty else { return }
        let count = photos.count
        let safeIndex = (index + count) % count
        let range = (-5...5).map { (safeIndex + $0 + count) % count }
        for i in range {
            let photo = photos[i]
            if loadedImages[photo.id.uuidString] == nil {
                loadedImages[photo.id.uuidString] = photo.image
            }
        }
    }
    
    private func calculateGeneralAge(for person: Person, at date: Date) -> String {
        let exactAge = AgeCalculator.calculate(for: person, at: date)
        
        if exactAge.isNewborn || (exactAge.years == 0 && exactAge.months == 0) {
            return "Birth Month"
        } else if exactAge.isPregnancy {
            return "Pregnancy"
        } else if exactAge.years == 0 {
            return "\(exactAge.months) month\(exactAge.months == 1 ? "" : "s")"
        } else {
            return "\(exactAge.years) year\(exactAge.years == 1 ? "" : "s")"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func getTitleText(for photo: Photo) -> String {
        switch titleOption {
        case .none: return ""
        case .name: return person.name
        case .age: return calculateGeneralAge(for: person, at: photo.dateTaken)
        case .date: return formatDate(photo.dateTaken)
        case .stackName: return sectionTitle ?? ""
        }
    }
    
    private func getSubtitleText(for photo: Photo) -> String {
        switch subtitleOption {
        case .none: return ""
        case .name: return person.name
        case .age: return calculateGeneralAge(for: person, at: photo.dateTaken)
        case .date: return formatDate(photo.dateTaken)
        case .stackName: return sectionTitle ?? ""
        }
    }
    
    // Timer Methods
    private func startTimer() {
        guard filteredPhotos.count > 1 else { return }
        let interval = 0.016
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            withAnimation(.linear(duration: interval)) {
                self.scrubberPosition += interval * self.playbackSpeed
                if self.scrubberPosition >= Double(self.filteredPhotos.count) {
                    self.scrubberPosition = 0
                }
                let newPhotoIndex = Int(self.scrubberPosition) % max(1, self.filteredPhotos.count)
                if newPhotoIndex != self.currentFilteredPhotoIndex {
                    self.currentFilteredPhotoIndex = newPhotoIndex
                    self.loadImagesAround(index: self.currentFilteredPhotoIndex)
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        scrubberPosition = Double(currentFilteredPhotoIndex)
    }
    
    private func groupAndSortPhotos() -> [(String, [Photo])] {
        return PhotoUtils.groupAndSortPhotos(for: person)
    }

    private var cancelButton: some View {
        Button("Cancel") {
            presentationMode.wrappedValue.dismiss()
        }
    }

    private var shareButton: some View {
        Button("Share") {
            showComingSoonAlert = true
        }
    }

    private var filteredPhotos: [Photo] {
        if person.pregnancyTracking == .none {
            return photos.filter { photo in
                let age = AgeCalculator.calculate(for: person, at: photo.dateTaken)
                return !age.isPregnancy
            }
        }
        return photos
    }

    private var availableSubtitleOptions: [TitleOption] {
        var options = TitleOption.allCases.filter { $0 != titleOption || $0 == .none }
        if sectionTitle == nil {
            options = options.filter { $0 != .stackName }
        }
        return options
    }
}

// LazyImage
struct LazyImage: View {
    let photo: Photo
    let loadedImage: UIImage?
    let aspectRatio: CGFloat
    let showAppIcon: Bool
    let titleText: String
    let subtitleText: String

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = loadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.width / aspectRatio)
                        .clipped()
                } else {
                    ProgressView()
                }
                
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            if !titleText.isEmpty {
                                Text(titleText)
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            
                            if !subtitleText.isEmpty {
                                Text(subtitleText)
                                    .font(.subheadline)
                                    .opacity(0.7)
                            }
                        }
                        .padding()
                        .foregroundColor(.white)
                        
                        Spacer()
                        
                        if showAppIcon {
                            Image("AppIcon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .padding(.vertical, 8)
                                .padding(.trailing, 16)
                        }
                    }
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0.5), Color.black.opacity(0)]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.width / aspectRatio)
            .background(Color.black.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }
}

struct PlayButton: View {
    @Binding var isPlaying: Bool
    
    var body: some View {
        Button(action: {
            isPlaying.toggle()
        }) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .foregroundColor(.blue)
                .font(.system(size: 18, weight: .bold))
        }
        .frame(width: 40, height: 40)
        .background(Color.clear)
        .clipShape(Circle())
    }
}

struct MusicSelectionView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Text("Music Selection Coming Soon")
                .navigationTitle("Select Music")
                .navigationBarItems(trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                })
        }
    }
}

// Add these new structs outside the main view
struct AspectRatio: Hashable, CustomStringConvertible {
    let value: CGFloat
    let description: String
    
    static let square = AspectRatio(value: 1.0, description: "Square")
    static let portrait = AspectRatio(value: 9.0/16.0, description: "9:16")
}


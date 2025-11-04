//
//  AppInfoView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/26/25.
//

import SwiftUI

struct AppInfoView: View {
    @EnvironmentObject var preferencesManager: PreferencesManager
    @Environment(\.presentationMode) var presentationMode

    private var preferences: AppPreferences { preferencesManager.preferences }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "Unknown"
    }
    
    private var copyright: String {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? "© 2025 George Knaggs"
    }
    
    var body: some View {
        NavigationView {
            appInfoContent
                .navigationTitle("App Info")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
        }
    }
    
    private var appInfoContent: some View {
        VStack(spacing: 30) {
            // App Icon and Title
            VStack(spacing: 16) {
                Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .cornerRadius(16)
                
                VStack(spacing: 4) {
                    Text("Rideshare Tracker")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Track your rideshare business")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Version Information
            VStack(spacing: 0) {
                InfoRow(label: "Version", value: appVersion)
                InfoRow(label: "Build", value: buildNumber)
                InfoRow(label: "Bundle ID", value: bundleIdentifier)
            }
            .background(Color(.systemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
            
            // Additional Information
            VStack(spacing: 16) {
                Text(copyright)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("Built with SwiftUI for iOS, iPadOS, and macOS")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Development Credits
                VStack(spacing: 4) {
                    Text("Developed by George Knaggs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("with Claude AI assistance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}
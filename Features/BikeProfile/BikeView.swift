//
//  BikeView.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 11/07/2026.
//


import SwiftUI

struct BikeView: View {

    @Environment(BikeProfileManager.self)
    private var manager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                BikeOverviewCard()

                BikeLearningCard()

                BikeAnalyticsCard(
                    context: manager.context
                )
            }
            .padding()
        }
        .navigationTitle("Bike")
        .navigationBarTitleDisplayMode(.large)
//        .onAppear {
//            manager.reloadProfiles()
//        }
    }
}

#Preview {
    NavigationStack {
        BikeView()
            .environment(BikeProfileManager.shared)
    }
}

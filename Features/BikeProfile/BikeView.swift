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

                BikeOverviewCard(
                    //context: manager.context
                )

                BikeLearningCard(
                    //context: manager.context
                )

                BikeAnalyticsCard(
                    context: manager.context
                )
            }
            .padding()
        }
        .navigationTitle("Bike")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        BikeView()
            .environment(BikeProfileManager.shared)
    }
}

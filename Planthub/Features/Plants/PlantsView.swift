import SwiftUI

struct PlantsView: View {
    var body: some View {
        NavigationStack {
            PlantEncyclopediaView()
            .background(Color.phBackground)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    PlantsView()
}

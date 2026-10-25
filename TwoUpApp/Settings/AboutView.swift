import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                section("What is Two-Up?", """
                Two-Up is a traditional Australian game. A person called the Spinner places two coins on a small paddle \
                called a kip and tosses them into the air while everyone stands in a ring around them. Players bet on \
                how the coins land: two heads, two tails, or one of each, which are called odds.
                """)

                section("The rules in this app", """
                • Two heads: the Spinner wins and keeps spinning.
                • Two tails: the Spinner loses and the spin passes to the next player.
                • Odds (one head, one tail): toss again. Five odds in a row and the Spinner loses.
                • The Spinner stakes on heads and other players "fade" it by covering the stake. Side bets on heads and \
                tails pay 1:1. The odds side bet pays a fixed 2:1.
                """)

                section("A little history", """
                Two-Up has been played in Australia since at least the gold rushes of the 1850s. It was widely played by \
                Australian soldiers, including during the First World War, and the game became bound up with how \
                25 April is remembered each year. That date marks the anniversary of the 1915 landings at Gallipoli and \
                honours those who served and died.
                """)

                section("Where real Two-Up is legal", """
                Playing Two-Up for money is illegal in most places in Australia, with an exception: it is allowed at \
                approved venues on 25 April. In Victoria, approved veterans' clubs may also be permitted to run it in \
                the days leading up to that date.

                Rules vary by state and territory and can change. Check with your state or territory gaming regulator \
                before taking part in anything involving real money.
                """)

                section("This app", """
                This app uses play money only. There is no real-money gambling, no purchases, no cash-out and no prizes. \
                It is made for entertainment and education, and is not connected with any veterans' or commemorative \
                organisation.
                """)

                Link("Gambling Help Online", destination: URL(string: "https://www.gamblinghelponline.org.au")!)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Palette.gum)
                    .frame(minHeight: 44)

                Text("Lest we forget.")
                    .font(.system(.body, design: .serif).italic())
                    .foregroundStyle(Palette.inkSoft)
            }
            .padding(20)
            .frame(maxWidth: 640, alignment: .leading)
        }
        .background(Palette.background)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text(body)
                .font(.body)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

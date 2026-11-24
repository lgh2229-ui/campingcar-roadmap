/// A number beside a restaurant is a taste/review score ranking, never a
/// nearby-distance rank. If no verified score exists, hide the numeric rank.
int? verifiedNearbyFoodRank(int? score, int? sourceRank) =>
    score == null ? null : sourceRank;

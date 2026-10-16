import 'package:flutter_test/flutter_test.dart';
import 'package:my_own_streaming_service/food_delivery.dart';

void main() {
  group('Food restaurant profiles', () {
    test('parses contact channels, hours, address and summary ratings', () {
      final restaurant = FoodRestaurant.fromJson({
        'id': 'restaurant-1',
        'name': 'All Day Cafe',
        'cuisine': 'Cafe',
        'address': '100 Main Street',
        'city': 'Mexico City',
        'phone': '+525500000000',
        'opening_hours': 'Mon-Fri 09:00-17:00; Sat-Sun Closed',
        'business_hours': {
          'mon': {'open': '09:00', 'close': '17:00', 'closed': false},
          'sat': {'closed': true},
          'sun': {'closed': true},
        },
        'contact_methods': ['call', 'whatsapp', 'imessage', 'email'],
        'whatsapp_number': '+525500000000',
        'imessage_address': 'cafe@example.com',
        'contact_email': 'support@example.com',
        'rating': 4.75,
        'review_count': 16,
      });
      expect(restaurant.address, '100 Main Street');
      expect(restaurant.openingHours, contains('Sat-Sun Closed'));
      expect(restaurant.businessHours['sat']['closed'], isTrue);
      expect(restaurant.contactMethods, containsAll(['call', 'whatsapp', 'imessage', 'email']));
      expect(restaurant.rating, 4.75);
      expect(restaurant.reviewCount, 16);
    });

    test('review model restricts ratings to the 1–5 display range', () {
      final review = FoodRestaurantReview.fromJson({
        'id': 'review-1', 'reviewer_display_name': 'Customer', 'rating': 5,
        'title': 'Great', 'body': 'Very good', 'verified_order': true,
      });
      expect(review.rating, 5);
      expect(review.verifiedOrder, isTrue);
    });

    test('themed marathon presets include concrete menu ideas', () {
      final wizarding = foodThemePresets.firstWhere((preset) => preset.key == 'wizarding_fantasy');
      final superhero = foodThemePresets.firstWhere((preset) => preset.key == 'superhero_marathon');
      expect(wizarding.menuIdeas, contains('Pumpkin pasties'));
      expect(wizarding.menuIdeas, contains('Treacle tart'));
      expect(superhero.menuIdeas, contains('Shawarma platter'));
      expect(superhero.menuIdeas, contains('Green smash burgers or green smoothies'));
    });
  });
}

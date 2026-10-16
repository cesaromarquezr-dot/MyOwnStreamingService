import 'package:flutter_test/flutter_test.dart';
import 'package:my_own_streaming_service/food_delivery.dart';

void main() {
  group('Food messaging models', () {
    test('parses menu ingredients and restaurant-declared allergens', () {
      final item = FoodMenuItem.fromJson({
        'id': 'menu-1',
        'name': 'Chicken Bowl',
        'category': 'Main',
        'description': 'Rice and chicken',
        'price_cents': 1299,
        'ingredients': ['rice', 'chicken', 'sesame oil'],
        'allergens': ['sesame'],
        'removable_ingredients': ['sesame oil'],
      });

      expect(item.ingredients, ['rice', 'chicken', 'sesame oil']);
      expect(item.allergens, ['sesame']);
      expect(item.removableIngredients, ['sesame oil']);
    });

    test('parses a conversation and a structured restaurant ingredient answer', () {
      final conversation = FoodConversation.fromJson({
        'id': 'conversation-1',
        'restaurant_id': 'restaurant-1',
        'restaurant_name': 'Example Kitchen',
        'customer_external_id': 'customer-1',
        'topic': 'ingredient_question',
        'subject': 'Ingredient and allergy question',
        'status': 'waiting_for_customer',
        'related_menu_item_name': 'Chicken Bowl',
        'messages': [
          {
            'id': 'message-1',
            'sender_role': 'customer',
            'message_type': 'ingredient_question',
            'body': 'Does this contain sesame?',
            'created_at': '2026-10-14T19:00:00Z',
            'metadata': {},
          },
          {
            'id': 'message-2',
            'sender_role': 'restaurant',
            'message_type': 'ingredient_answer',
            'body': 'The item contains sesame. Cross-contact cannot be ruled out.',
            'created_at': '2026-10-14T19:01:00Z',
            'metadata': {
              'ingredient': 'sesame',
              'presence': 'contains',
              'removal': 'cannot_remove',
              'crossContact': 'cannot_rule_out',
              'restaurantConfirmed': true,
            },
          },
        ],
      });

      expect(conversation.restaurantName, 'Example Kitchen');
      expect(conversation.topic, 'ingredient_question');
      expect(conversation.relatedMenuItemName, 'Chicken Bowl');
      expect(conversation.messages, hasLength(2));
      expect(conversation.messages.last.senderRole, 'restaurant');
      expect(conversation.messages.last.messageType, 'ingredient_answer');
      expect(conversation.messages.last.metadata['restaurantConfirmed'], isTrue);
    });
  });
}

// lib/screens/profile/faq_screen.dart
import 'package:flutter/material.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQ & Help'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _FAQItem(
            question: 'How do I generate a recipe?',
            answer: 'You can generate a recipe by typing an ingredient or dish name in the search box on the home screen and tapping the search button. Kitchen Assistant will create a complete recipe with ingredients, steps, and images for you.',
          ),
          _FAQItem(
            question: 'Can I save recipes for later?',
            answer: 'Yes! Once a recipe is generated, you\'ll see an option to save it. Saved recipes can be accessed from your "Recipes" tab. You can also favorite recipes to find them quickly.',
          ),
          _FAQItem(
            question: 'How does the chat feature work?',
            answer: 'The chat feature lets you have a conversation with our cooking assistant. You can ask cooking questions, get recipe ideas, or get help with specific techniques. Tap on suggestions to explore options or generate recipes.',
          ),
          _FAQItem(
            question: 'How do I set my dietary preferences?',
            answer: 'Go to your profile tab and select "Edit Cooking Preferences". There you can set your dietary restrictions, allergies, favorite cuisines, and cooking skill level.',
          ),
          _FAQItem(
            question: 'Can I edit a generated recipe?',
            answer: 'Currently, recipes cannot be edited after generation. However, you can always generate a new recipe with more specific instructions to get the results you want.',
          ),
          _FAQItem(
            question: 'How accurate is the nutritional information?',
            answer: 'The nutritional information provided is an estimate based on standard ingredients and portions. Actual values may vary depending on specific products and preparation methods.',
          ),
          _FAQItem(
            question: 'What if I have an allergy?',
            answer: 'You can set your allergies in your profile preferences. Kitchen Assistant will try to avoid suggesting recipes with those allergens, but always double-check ingredients for your safety.',
          ),
          _FAQItem(
            question: 'How do I contact support?',
            answer: 'You can contact our support team by clicking on "Contact Support" in the Profile tab under Help & Support, or by emailing support@Kitchenassistant.com.',
          ),
        ],
      ),
    );
  }
}

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FAQItem({
    Key? key,
    required this.question,
    required this.answer,
  }) : super(key: key);

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: Text(
          widget.question,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        trailing: Icon(
          _expanded ? Icons.expand_less : Icons.expand_more,
          color: Theme.of(context).primaryColor,
        ),
        onExpansionChanged: (expanded) {
          setState(() {
            _expanded = expanded;
          });
        },
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              widget.answer,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
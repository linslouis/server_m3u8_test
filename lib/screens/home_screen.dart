import 'package:flutter/material.dart';
import '../widgets/reels_pager.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Short Video Feed App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Advanced HLS Video Feed Demo',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Features:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _buildFeaturesList(),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ReelsPager(),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Video Feed'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFeaturesList() {
    final features = [
      'Vertical swipeable video feed',
      'HLS adaptive bitrate streaming',
      'Preview clips with seamless transition',
      'Smart buffer management',
      'Predictive preloading',
      'Hardware decoder pooling',
    ];
    
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: features.map((feature) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(feature),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
} 
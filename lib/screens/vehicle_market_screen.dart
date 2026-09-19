import 'package:flutter/material.dart';

class VehicleMarketScreen extends StatefulWidget {
  const VehicleMarketScreen({super.key});

  @override
  State<VehicleMarketScreen> createState() => _VehicleMarketScreenState();
}

class _VehicleMarketScreenState extends State<VehicleMarketScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('차량중고마켓')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: SearchBar(
              controller: _search,
              hintText: '캠핑카, 모델명 검색',
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_car_outlined, size: 58),
                    const SizedBox(height: 14),
                    Text(_query.isEmpty ? '등록된 중고 캠핑카가 없습니다.' : '검색 결과가 없습니다.', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text('캠핑카 매물 등록·검색 기능을 위한 전용 메뉴입니다.\n매물 등록 기능은 다음 단계에서 연결됩니다.', textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('차량 매물 등록 기능을 준비 중입니다.'))),
        icon: const Icon(Icons.add),
        label: const Text('차량 등록'),
      ),
    );
  }
}

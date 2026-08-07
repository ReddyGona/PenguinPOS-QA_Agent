import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';

/// Dedicated SKU item row widget in the Order Suite configuration table with 2 clean Dropdowns and consistent layout.
class SkuItemRow extends StatelessWidget {
  const SkuItemRow({
    super.key,
    required this.index,
    required this.item,
    required this.skuCodeController,
    required this.weightController,
    required this.running,
    required this.onUpdateItem,
    required this.onRemoveItem,
  });

  final int index;
  final OrderItem item;
  final TextEditingController? skuCodeController;
  final TextEditingController? weightController;
  final bool running;
  final ValueChanged<OrderItem> onUpdateItem;
  final VoidCallback onRemoveItem;

  @override
  Widget build(BuildContext context) {
    final isManual = item.entryMode == ItemEntryMode.manual;
    final isBizerba = item.type == SkuItemType.bizerba;
    final isWeighed = item.isWeighed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          // Index Number
          SizedBox(
            width: 28,
            child: Text(
              '#${index + 1}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 1. SKU Code / Barcode Input Field
          Expanded(
            flex: 3,
            child: TextField(
              key: ValueKey<String>('sku-${item.rowId}'),
              controller: skuCodeController,
              enabled: !running,
              keyboardType: isBizerba
                  ? TextInputType.text
                  : (isManual ? TextInputType.number : TextInputType.text),
              inputFormatters: (!isBizerba && isManual)
                  ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
                  : null,
              decoration: InputDecoration(
                labelText: isBizerba
                    ? 'Bizerba Barcode'
                    : (isManual ? 'Numeric Code' : 'SKU Code'),
                hintText: isBizerba
                    ? 'e.g. 10000001W2.45'
                    : (isManual ? 'e.g. 1001' : 'Enter SKU code'),
                isDense: true,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
              onChanged: (val) {
                onUpdateItem(item.copyWith(skuCode: val));
              },
            ),
          ),
          const SizedBox(width: 10),

          // 2. Weight Input Field (Always rendered in 2nd place for layout consistency, disabled if non-weighed)
          SizedBox(
            width: 95,
            child: TextField(
              key: ValueKey<String>('weight-${item.rowId}-${item.type.name}'),
              controller: weightController,
              enabled: !running && isWeighed,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Weight (kg)',
                hintText: isWeighed ? 'e.g. 2.345' : 'N/A',
                isDense: true,
                border: const OutlineInputBorder(),
                filled: !isWeighed,
                fillColor: !isWeighed ? const Color(0xFFF1F5F9) : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
              onChanged: (val) {
                final parsed = double.tryParse(val);
                onUpdateItem(
                  item.copyWith(type: SkuItemType.weighed, weight: parsed),
                );
              },
            ),
          ),
          const SizedBox(width: 10),

          // 3. Dropdown 1: Entry Mode (Scan vs Manual Entry)
          SizedBox(
            width: 145,
            child: DropdownButtonFormField<ItemEntryMode>(
              key: ValueKey<String>(
                'entry-${item.rowId}-${item.entryMode.name}',
              ),
              initialValue: item.entryMode,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: Color(0xFF64748B),
              ),
              decoration: const InputDecoration(
                labelText: 'Entry Mode',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
              items: ItemEntryMode.values.map((mode) {
                return DropdownMenuItem<ItemEntryMode>(
                  value: mode,
                  child: Text(
                    mode.label,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: running
                  ? null
                  : (newMode) {
                      if (newMode != null) {
                        onUpdateItem(item.copyWith(entryMode: newMode));
                      }
                    },
            ),
          ),
          const SizedBox(width: 10),

          // 4. Dropdown 2: Item Type (Non-Weighed vs Weighed vs Bizerba)
          SizedBox(
            width: 165,
            child: DropdownButtonFormField<SkuItemType>(
              key: ValueKey<String>('type-${item.rowId}-${item.type.name}'),
              initialValue: item.type,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: Color(0xFF64748B),
              ),
              decoration: const InputDecoration(
                labelText: 'Item Type',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
              items: SkuItemType.values.map((type) {
                return DropdownMenuItem<SkuItemType>(
                  value: type,
                  child: Text(
                    type.label,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: running
                  ? null
                  : (newType) {
                      if (newType != null) {
                        final parsedWeight = double.tryParse(
                          weightController?.text ?? '',
                        );
                        onUpdateItem(
                          item.copyWith(
                            type: newType,
                            weight: newType == SkuItemType.weighed
                                ? parsedWeight
                                : null,
                          ),
                        );
                      }
                    },
            ),
          ),

          const SizedBox(width: 8),

          // Delete Row Button
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 20,
              color: Color(0xFFEF4444),
            ),
            onPressed: running ? null : onRemoveItem,
          ),
        ],
      ),
    );
  }
}

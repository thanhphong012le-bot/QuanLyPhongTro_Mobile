import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_client.dart';
import '../core/formatters.dart';
import '../models/room.dart';
import '../services/meter_ocr_service.dart';
import 'meter_crop_dialog.dart';

class InvoiceFormScreen extends StatefulWidget {
  const InvoiceFormScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ocr = MeterOcrService();
  final _imagePicker = ImagePicker();

  List<Room> _rooms = const [];
  int? _roomId;
  bool _loadingRooms = true;
  bool _saving = false;
  bool _readingElectric = false;
  bool _readingWater = false;

  String? _electricImagePath;
  String? _waterImagePath;
  String _electricRawText = '';
  String _waterRawText = '';
  DateTime? _electricCapturedAt;
  DateTime? _waterCapturedAt;
  List<int> _electricCandidates = const [];
  List<int> _waterCandidates = const [];
  List<MeterOcrChoice> _electricChoices = const [];
  List<WaterOcrChoice> _waterChoices = const [];
  MeterReadMode _electricMode = MeterReadMode.automatic;
  WaterReadMode _waterMode = WaterReadMode.automatic;
  String _electricOcrMessage = '';
  String _waterOcrMessage = '';
  String? _electricOcrPath;
  bool _electricManualRegion = false;
  String? _waterOcrPath;
  bool _waterManualRegion = false;

  final _month = TextEditingController(text: DateTime.now().month.toString());
  final _year = TextEditingController(text: DateTime.now().year.toString());
  final _electricOld = TextEditingController(text: '0');
  final _electricNew = TextEditingController();
  final _waterOld = TextEditingController(text: '0');
  final _waterNew = TextEditingController();

  @override
  void initState() {
    super.initState();
    _electricNew.addListener(_refreshBillPreview);
    _waterNew.addListener(_refreshBillPreview);
    _loadRooms();
  }

  @override
  void dispose() {
    _electricNew.removeListener(_refreshBillPreview);
    _waterNew.removeListener(_refreshBillPreview);
    _month.dispose();
    _year.dispose();
    _electricOld.dispose();
    _electricNew.dispose();
    _waterOld.dispose();
    _waterNew.dispose();
    super.dispose();
  }

  void _refreshBillPreview() {
    if (mounted) setState(() {});
  }

  Room? get _selectedRoom {
    final roomId = _roomId;
    if (roomId == null) return null;
    for (final room in _rooms) {
      if (room.id == roomId) return room;
    }
    return null;
  }

  Future<void> _loadRooms() async {
    try {
      final data = await widget.api.get('/rooms') as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _rooms = data
            .map((e) => Room.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tải được danh sách phòng.')),
      );
    } finally {
      if (mounted) setState(() => _loadingRooms = false);
    }
  }

  Future<void> _selectRoom(int? roomId) async {
    setState(() {
      _roomId = roomId;
      _electricNew.clear();
      _waterNew.clear();
      _electricImagePath = null;
      _waterImagePath = null;
      _electricRawText = '';
      _waterRawText = '';
      _electricCandidates = const [];
      _waterCandidates = const [];
      _electricChoices = const [];
      _waterChoices = const [];
      _electricOcrMessage = '';
      _waterOcrMessage = '';
      _electricOcrPath = null;
      _waterOcrPath = null;
      _electricManualRegion = false;
      _waterManualRegion = false;
      _electricCapturedAt = null;
      _waterCapturedAt = null;
    });
    if (roomId == null) return;

    try {
      final data = await widget.api.get('/invoices/last-readings/$roomId');
      if (!mounted) return;
      final map = Map<String, dynamic>.from(data as Map);
      setState(() {
        _electricOld.text = '${(map['electricOld'] as num?)?.toInt() ?? 0}';
        _waterOld.text = '${(map['waterOld'] as num?)?.toInt() ?? 0}';
        _month.text = '${(map['month'] as num?)?.toInt() ?? DateTime.now().month}';
        _year.text = '${(map['year'] as num?)?.toInt() ?? DateTime.now().year}';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  int? _int(String value) => int.tryParse(value.trim());

  Future<void> _captureMeter({required bool electric}) async {
    if (_roomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy chọn phòng trước khi chụp công tơ.')),
      );
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 95,
        maxWidth: 2200,
      );
      if (image == null) return;
      await _processMeterImage(
        electric: electric,
        path: image.path,
        capturedAt: DateTime.now(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không mở/chụp được camera: $e')),
      );
    }
  }

  Future<void> _pickMeterFromDevice({required bool electric}) async {
    if (_roomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy chọn phòng trước khi đọc công tơ.')),
      );
      return;
    }

    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;

    final path = file.path;
    if (path == null || path.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không lấy được đường dẫn của ảnh.')),
      );
      return;
    }

    await _processMeterImage(
      electric: electric,
      path: path,
      capturedAt: DateTime.now(),
    );
  }
  Future<void> _startMeterScan({required bool electric}) async {
  if (_roomId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hãy chọn phòng trước khi quét chỉ số.')),
    );
    return;
  }

  if (electric) {
    final mode = await _chooseElectricScanMode();
    if (mode == null || !mounted) return;

    setState(() {
      _electricMode = mode;
      _electricNew.clear();
    });
  } else {
    final mode = await _chooseWaterScanMode();
    if (mode == null || !mounted) return;

    setState(() {
      _waterMode = mode;
      _waterNew.clear();
    });
  }

  if (!mounted) return;

  final source = await _chooseScanSource(electric: electric);
  if (source == null || !mounted) return;

  if (source == 'camera') {
    await _captureMeter(electric: electric);
  } else {
    await _pickMeterFromDevice(electric: electric);
  }
}

Future<MeterReadMode?> _chooseElectricScanMode() {
  return showModalBottomSheet<MeterReadMode>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Chọn loại công tơ điện',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ListTile(
            title: const Text('Tự động'),
            subtitle: const Text('Tự nhận diện loại công tơ'),
            onTap: () => Navigator.pop(context, MeterReadMode.automatic),
          ),
          ListTile(
            title: const Text('Đồng hồ cơ'),
            subtitle: const Text('Đọc chỉ số công tơ cơ'),
            onTap: () => Navigator.pop(context, MeterReadMode.mechanical),
          ),
          ListTile(
            title: const Text('Đồng hồ điện tử'),
            subtitle: const Text('Đọc chỉ số màn hình LCD'),
            onTap: () => Navigator.pop(context, MeterReadMode.electronic),
          ),
        ],
      ),
    ),
  );
}

Future<WaterReadMode?> _chooseWaterScanMode() {
  return showModalBottomSheet<WaterReadMode>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Chọn loại đồng hồ nước',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ListTile(
            title: const Text('Tự động'),
            subtitle: const Text('Tự nhận diện loại đồng hồ'),
            onTap: () => Navigator.pop(context, WaterReadMode.automatic),
          ),
          ListTile(
            title: const Text('Đồng hồ 4 chữ số'),
            subtitle: const Text('Đọc 4 số chính'),
            onTap: () => Navigator.pop(context, WaterReadMode.roundFourDigits),
          ),
          ListTile(
            title: const Text('Đồng hồ 5 chữ số'),
            subtitle: const Text('Đọc 5 số chính'),
            onTap: () => Navigator.pop(context, WaterReadMode.blueFiveDigits),
          ),
        ],
      ),
    ),
  );
}

Future<String?> _chooseScanSource({required bool electric}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                electric ? 'Quét công tơ điện' : 'Quét đồng hồ nước',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ListTile(
            title: const Text('Chụp ảnh'),
            subtitle: const Text('Mở camera để chụp'),
            onTap: () => Navigator.pop(context, 'camera'),
          ),
          ListTile(
            title: const Text('Chọn ảnh'),
            subtitle: const Text('Chọn ảnh có sẵn'),
            onTap: () => Navigator.pop(context, 'gallery'),
          ),
        ],
      ),
    ),
  );
}
  Future<void> _processMeterImage({
    required bool electric,
    required String path,
    required DateTime capturedAt,
    String? originalPath,
    bool manualRegion = false,
  }) async {
    final scanningRoomId = _roomId;
    if (electric) {
      _electricNew.clear();
    } else {
      _waterNew.clear();
    }
    final previousReading = electric
        ? (_int(_electricOld.text) ?? 0)
        : (_int(_waterOld.text) ?? 0);

    setState(() {
      if (electric) {
        _electricImagePath = originalPath ?? path;
        _electricOcrPath = path;
        _electricManualRegion = manualRegion;
        _electricCapturedAt = capturedAt;
        _readingElectric = true;
        _electricRawText = '';
        _electricCandidates = const [];
        _electricChoices = const [];
        _electricOcrMessage = '';
      } else {
        _waterImagePath = originalPath ?? path;
        _waterOcrPath = path;
        _waterManualRegion = manualRegion;
        _waterCapturedAt = capturedAt;
        _readingWater = true;
        _waterRawText = '';
        _waterCandidates = const [];
        _waterChoices = const [];
        _waterOcrMessage = '';
      }
    });

    try {
      final result = await _ocr.recognize(
        path,
        previousReading: previousReading,
        electric: electric,
        mode: electric ? _electricMode : MeterReadMode.automatic,
        waterMode: _waterMode,
        manualRegion: manualRegion,
      );
      if (!mounted || scanningRoomId != _roomId) return;

      setState(() {
        if (electric) {
          _electricRawText = result.rawText;
          _electricCandidates = result.candidates;
          _electricChoices = result.choices;
          _electricOcrMessage = result.message;
        } else {
          _waterRawText = result.rawText;
          _waterCandidates = result.candidates;
          _waterChoices = result.waterChoices;
          _waterOcrMessage = result.message;
        }
      });

      int? chosen = result.suggestedValue;
      if (chosen == null && electric && result.choices.isNotEmpty) {
        chosen = await _chooseElectricChoice(
          result.choices,
          previousReading,
        );
      } else if (chosen == null && !electric && result.waterChoices.isNotEmpty) {
        chosen = await _chooseWaterChoice(
          result.waterChoices,
          previousReading,
        );
      }

      if (!mounted || scanningRoomId != _roomId) return;
      if (chosen != null) {
        final controller = electric ? _electricNew : _waterNew;
        controller.text = '$chosen';
        final roomName = _selectedRoom?.roomName ?? 'phòng đã chọn';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã quét ${electric ? 'điện' : 'nước'} của $roomName: $chosen. Hãy đối chiếu ảnh trước khi lưu.',
            ),
          ),
        );
      } else if (result.candidates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'OCR chưa nhận ra chỉ số rõ ràng. Hãy chụp gần hơn hoặc nhập số thủ công.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không đọc được ảnh: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          if (electric) {
            _readingElectric = false;
          } else {
            _readingWater = false;
          }
        });
      }
    }
  }

  Future<int?> _chooseElectricChoice(
    List<MeterOcrChoice> choices,
    int previousReading,
  ) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Xác nhận chỉ số điện OCR',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Chỉ số tháng trước: $previousReading kWh'),
              const Text(
                'OCR không xác định chắc chắn loại đồng hồ. '
                'Hãy đối chiếu ô số thật trên ảnh trước khi chọn.',
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.46,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: choices.length,
                  itemBuilder: (_, index) {
                    final choice = choices[index];
                    return ListTile(
                      leading: const Icon(Icons.electric_meter_outlined),
                      title: Text('${choice.value} kWh'),
                      subtitle: Text(
                        '${choice.mode == MeterReadMode.mechanical ? 'Điện cơ — lấy 5/6 số' : 'Điện tử/LCD'} • OCR: ${choice.source}'
                        '${choice.hasDecimal ? ' • Có số lẻ, chỉ lấy phần nguyên' : ''}',
                      ),
                      onTap: () => Navigator.pop(sheetContext, choice.value),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(sheetContext),
                icon: const Icon(Icons.crop_free),
                label: const Text('Không đúng — khoanh vùng số rồi quét lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<int?> _chooseWaterChoice(
    List<WaterOcrChoice> choices,
    int previousReading,
  ) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Xác nhận chỉ số nước OCR',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Chỉ số tháng trước: $previousReading'),
              const Text(
                'Ứng dụng chỉ dùng một dãy số thuần. Nếu chưa biết đồng hồ là loại 4 hay 5 số, hãy chọn đúng theo mặt đồng hồ.',
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.46,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: choices.length,
                  itemBuilder: (_, index) {
                    final choice = choices[index];
                    return ListTile(
                      leading: const Icon(Icons.water_drop_outlined),
                      title: Text('${choice.value}'),
                      subtitle: Text(
                        '${choice.digitCount} số chính • Dãy OCR: ${choice.source}',
                      ),
                      onTap: () => Navigator.pop(sheetContext, choice.value),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(sheetContext),
                icon: const Icon(Icons.crop_free),
                label: const Text('Không đúng — khoanh vùng số rồi quét lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cropAndScan({required bool electric}) async {
    final original = electric ? _electricImagePath : _waterImagePath;
    if (original == null) return;
    try {
      final cropped = await showMeterReadingCropDialog(context, original);
      if (cropped == null || !mounted) return;
      await _processMeterImage(
        electric: electric,
        path: cropped,
        originalPath: original,
        manualRegion: true,
        capturedAt: electric
            ? (_electricCapturedAt ?? DateTime.now())
            : (_waterCapturedAt ?? DateTime.now()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không cắt/quét được vùng số: $e')),
      );
    }
  }

  Future<int?> _chooseCandidate({
    required String title,
    required List<int> candidates,
    required int previousReading,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text('Chỉ số tháng trước: $previousReading'),
              const SizedBox(height: 6),
              const Text(
                'Ảnh có thể chứa số seri hoặc thông tin khác. Hãy chọn đúng số đang hiển thị trên công tơ.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: candidates
                    .map(
                      (value) => ActionChip(
                        avatar: const Icon(Icons.numbers, size: 18),
                        label: Text('$value'),
                        onPressed: () => Navigator.pop(context, value),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _roomId == null) return;

    final electricOld = _int(_electricOld.text)!;
    final electricNew = _int(_electricNew.text)!;
    final waterOld = _int(_waterOld.text)!;
    final waterNew = _int(_waterNew.text)!;

    if (electricNew < electricOld || waterNew < waterOld) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chỉ số mới không được nhỏ hơn chỉ số cũ.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận chỉ số'),
        content: Text(
          'Điện: $electricOld → $electricNew\n'
          'Nước: $waterOld → $waterNew\n\n'        
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kiểm tra lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tạo hóa đơn'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      final result = await widget.api.post('/invoices', body: {
        'roomId': _roomId,
        'month': _int(_month.text),
        'year': _int(_year.text),
        'electricOld': electricOld,
        'electricNew': electricNew,
        'waterOld': waterOld,
        'waterNew': waterNew,
      });
      if (!mounted) return;

      final map = result is Map ? Map<String, dynamic>.from(result) : <String, dynamic>{};
      final total = (map['totalAmount'] as num?)?.toDouble();
      if (total != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã tạo hóa đơn: ${formatVnd(total)}')),
        );
      }
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _numberField(
    String label,
    TextEditingController controller, {
    bool readOnly = false,
    int? minValue,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final parsed = value == null ? null : _int(value);
        if (parsed == null) return 'Vui lòng nhập số hợp lệ';
        if (minValue != null && parsed < minValue) {
          return 'Phải ≥ $minValue';
        }
        return null;
      },
    );
  }

  Widget _meterCard({required bool electric}) {
    final title = electric ? 'Công tơ điện' : 'Đồng hồ nước';
    final icon = electric ? Icons.electric_meter_outlined : Icons.water_drop_outlined;
    final imagePath = electric ? _electricImagePath : _waterImagePath;
    final rawText = electric ? _electricRawText : _waterRawText;
    final candidates = electric ? _electricCandidates : _waterCandidates;
    final ocrPath = electric ? _electricOcrPath : _waterOcrPath;
    final manuallyCropped = electric ? _electricManualRegion : _waterManualRegion;
    final processing = electric ? _readingElectric : _readingWater;
    final capturedAt = electric ? _electricCapturedAt : _waterCapturedAt;
    final oldController = electric ? _electricOld : _waterOld;
    final newController = electric ? _electricNew : _waterNew;
    final oldValue = _int(oldController.text) ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _numberField('Chỉ số cũ', oldController, readOnly: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _numberField(
                    'Chỉ số mới',
                    newController,
                    minValue: oldValue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (processing)
  FilledButton.tonalIcon(
    onPressed: null,
    icon: const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
    label: const Text('Đang nhận dạng...'),
  )
else
  FilledButton.icon(
    onPressed: () => _startMeterScan(electric: electric),
    icon: const Icon(Icons.document_scanner_outlined),
    label: const Padding(
      padding: EdgeInsets.symmetric(vertical: 11),
      child: Text('Quét hình ảnh'),
    ),
  ),
            if (imagePath != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: processing ? null : () => _cropAndScan(electric: electric),
                icon: const Icon(Icons.crop_free),
                label: const Text('Khoanh vùng chỉ số trên ảnh và quét lại'),
              ),
              if (manuallyCropped && ocrPath != null) ...[
                const SizedBox(height: 6),
                const Text('Vùng số vừa quét:', style: TextStyle(fontSize: 12)),
                Image.file(File(ocrPath), height: 90, fit: BoxFit.contain),
              ],
            ],
            if (electric && _electricOcrMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _electricOcrMessage,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ],
            if (!electric && _waterOcrMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _waterOcrMessage,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ],
            if (candidates.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Chỉ số OCR đề xuất — hãy đối chiếu trên ảnh:',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: electric
                    ? _electricChoices.map(
                        (choice) => ActionChip(
                          label: Text('${choice.value} (${choice.mode == MeterReadMode.mechanical ? 'Cơ' : 'LCD'})'),
                          tooltip: 'OCR: ${choice.source} — ${choice.mode == MeterReadMode.mechanical ? 'Điện cơ' : 'LCD'}',
                          onPressed: () => newController.text = '${choice.value}',
                        ),
                      ).toList()
                    : _waterChoices.map(
                        (choice) => ActionChip(
                          label: Text('${choice.value} (${choice.digitCount} số)'),
                          tooltip: 'Dãy OCR: ${choice.source} — ${choice.digitCount} số chính',
                          onPressed: () => newController.text = '${choice.value}',
                        ),
                      ).toList(),
              ),
            ],
            if (rawText.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('Xem văn bản OCR nhận được'),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(rawText),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _billPreview() {
    final room = _selectedRoom;
    if (room == null) return const SizedBox.shrink();

    final electricOld = _int(_electricOld.text) ?? 0;
    final electricNew = _int(_electricNew.text);
    final waterOld = _int(_waterOld.text) ?? 0;
    final waterNew = _int(_waterNew.text);

    final electricUnits = electricNew == null || electricNew < electricOld
        ? 0
        : electricNew - electricOld;
    final waterUnits = waterNew == null || waterNew < waterOld
        ? 0
        : waterNew - waterOld;
    final electricity = electricUnits * room.electricPrice;
    final water = waterUnits * room.waterPrice;
    final wifi = room.hasWifi ? room.wifiPrice : 0;
    final total = room.price + electricity + water + wifi + room.trashPrice;

    Widget row(String label, String value, {bool strong = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              value,
              style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tạm tính hóa đơn',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            row('Tiền phòng', formatVnd(room.price)),
            row(
              'Điện: $electricUnits × ${formatVnd(room.electricPrice)}',
              formatVnd(electricity),
            ),
            row(
              'Nước: $waterUnits × ${formatVnd(room.waterPrice)}',
              formatVnd(water),
            ),
            row('WiFi', formatVnd(wifi)),
            row('Rác', formatVnd(room.trashPrice)),
            const Divider(height: 20),
            row('TỔNG DỰ KIẾN', formatVnd(total), strong: true),
            const SizedBox(height: 8),
            
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedRoom = _selectedRoom;

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo hóa đơn điện nước')),
      body: _loadingRooms
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _roomId,
                    decoration: const InputDecoration(labelText: 'Chọn phòng'),
                    items: _rooms
                        .map(
                          (room) => DropdownMenuItem<int>(
                            value: room.id,
                            child: Text(
                              room.tenantUsername == null || room.tenantUsername!.isEmpty
                                  ? '${room.roomName} '
                                  : '${room.roomName} - ${room.tenantUsername}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _selectRoom,
                    validator: (value) => value == null ? 'Vui lòng chọn phòng' : null,
                  ),
                  if (selectedRoom != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Người thuê: ${selectedRoom.tenantUsername?.isNotEmpty == true ? selectedRoom.tenantUsername : 'Chưa gán'}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _numberField('Tháng', _month)),
                      const SizedBox(width: 12),
                      Expanded(child: _numberField('Năm', _year)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _meterCard(electric: true),
                  const SizedBox(height: 12),
                  _meterCard(electric: false),
                  const SizedBox(height: 12),
                  _billPreview(),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.calculate_outlined),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(_saving ? 'Đang lưu...' : 'Xác nhận & tạo hóa đơn'),
                    ),
                   
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

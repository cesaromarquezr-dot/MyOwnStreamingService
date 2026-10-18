import 'package:flutter/material.dart';
import 'backend_api.dart';

/// Customer help centre and authenticated ticket list/create experience.
class CustomerSupportScreen extends StatefulWidget {
  const CustomerSupportScreen({super.key, this.api});
  final BackendApi? api;
  @override State<CustomerSupportScreen> createState() => _CustomerSupportScreenState();
}

class _CustomerSupportScreenState extends State<CustomerSupportScreen> {
  static const bg = Color(0xFF101018), surface = Color(0xFF1B1B28), accent = Color(0xFF9B8CFF);
  late final BackendApi api = widget.api ?? BackendApi();
  final subject = TextEditingController(), description = TextEditingController();
  String category = 'playback', priority = 'normal';
  bool loading = false, staffView = false;
  final staffReply = TextEditingController();
  String? message;
  List<Map<String, dynamic>> tickets = [];
  @override void initState() { super.initState(); _loadTickets(); }
  @override void dispose() { subject.dispose(); description.dispose(); staffReply.dispose(); super.dispose(); }
  Future<void> _loadTickets() async {
    if (!api.isAuthenticated) { if (mounted) setState(() => message = 'Sign in to create tickets and view your support history.'); return; }
    setState(() { loading = true; message = null; });
    try { final result = await api.listSupportTickets(allTickets: staffView); if (mounted) setState(() => tickets = result); }
    catch (e) { if (mounted) setState(() => message = e.toString()); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> _setTicket(Map<String, dynamic> ticket, String status) async {
    final id = ticket['id']?.toString() ?? ''; if (id.isEmpty) return;
    setState(() { loading = true; message = null; });
    try { await api.updateSupportTicket(ticketId: id, status: status, reply: staffReply.text.trim()); staffReply.clear(); if (mounted) setState(() => message = 'Ticket updated.'); await _loadTickets(); }
    catch (e) { if (mounted) setState(() => message = e.toString()); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> _submit() async {
    if (subject.text.trim().isEmpty || description.text.trim().isEmpty) { setState(() => message = 'Add a subject and describe the issue first.'); return; }
    setState(() { loading = true; message = null; });
    try {
      final result = await api.createSupportTicket(subject: subject.text.trim(), category: category, priority: priority, description: description.text.trim());
      subject.clear(); description.clear();
      if (mounted) setState(() => message = 'Ticket created: ${result['ticket']?['id'] ?? 'submitted'}.');
      await _loadTickets();
    } catch (e) { if (mounted) setState(() => message = e.toString()); }
    finally { if (mounted) setState(() => loading = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: bg,
    appBar: AppBar(title: const Text('Customer Support'), backgroundColor: bg),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: const LinearGradient(colors: [Color(0xFF30254E), Color(0xFF1B263B)])), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.support_agent_rounded, color: accent, size: 36), SizedBox(height: 10), Text('We’re here to help.', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)), SizedBox(height: 6), Text('Report playback, account, billing, device, social, shop, or delivery issues. Track your requests here.', style: TextStyle(color: Colors.white70, height: 1.4))])),
      const SizedBox(height: 18), _sectionTitle('Create a support ticket'),
      _field(subject, 'Subject', 'Briefly describe the issue'),
      const SizedBox(height: 10), DropdownButtonFormField<String>(initialValue: category, dropdownColor: surface, decoration: _decoration('Category'), items: const [('account','Account'),('billing','Billing'),('playback','Playback & streaming'),('devices','Devices'),('music','Music'),('social','Social & Watch Party'),('shop','Shop'),('food_delivery','Food delivery'),('privacy','Privacy & security'),('other','Other')].map((v) => DropdownMenuItem(value: v.$1, child: Text(v.$2))).toList(), onChanged: (v) => setState(() => category = v ?? 'other')),
      const SizedBox(height: 10), DropdownButtonFormField<String>(initialValue: priority, dropdownColor: surface, decoration: _decoration('Priority'), items: const [('low','Low'),('normal','Normal'),('high','High'),('urgent','Urgent')].map((v) => DropdownMenuItem(value: v.$1, child: Text(v.$2))).toList(), onChanged: (v) => setState(() => priority = v ?? 'normal')),
      const SizedBox(height: 10), _field(description, 'What happened?', 'Include steps to reproduce the issue', lines: 5),
      const SizedBox(height: 12), FilledButton.icon(onPressed: loading ? null : _submit, icon: const Icon(Icons.send_rounded), label: Text(loading ? 'Working…' : 'Submit ticket'), style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white, padding: const EdgeInsets.all(15))),
      if (message != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(message!, style: const TextStyle(color: Colors.white70))),
      const SizedBox(height: 24), Row(children: [Expanded(child: _sectionTitle(staffView ? 'Support team queue' : 'Your tickets')), TextButton.icon(onPressed: loading ? null : () { setState(() => staffView = !staffView); _loadTickets(); }, icon: Icon(staffView ? Icons.person_outline : Icons.support_agent, color: accent), label: Text(staffView ? 'My tickets' : 'Staff view', style: const TextStyle(color: accent)))]),
      if (loading && tickets.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
      if (!loading && tickets.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('No tickets to show yet. Sign in and submit a request to get started.', style: TextStyle(color: Colors.white60))),
      for (final ticket in tickets) Card(color: surface, child: Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ListTile(leading: const Icon(Icons.confirmation_number_outlined, color: accent), title: Text(ticket['subject']?.toString() ?? 'Support request', style: const TextStyle(color: Colors.white)), subtitle: Text('${ticket['category'] ?? 'other'} • ${ticket['priority'] ?? 'normal'}', style: const TextStyle(color: Colors.white60)), trailing: _status(ticket['status']?.toString() ?? 'open')), if (staffView) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: TextField(controller: staffReply, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: _decoration('Staff reply (optional)').copyWith(hintText: 'Reply to the customer'))), if (staffView) Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), child: Wrap(spacing: 8, runSpacing: 8, children: [for (final status in ['in_progress','waiting_on_customer','resolved','closed']) OutlinedButton(onPressed: loading ? null : () => _setTicket(ticket, status), child: Text(status.replaceAll('_', ' ')))]))]))),
      const SizedBox(height: 18), _sectionTitle('Other ways to get help'),
      const ListTile(leading: Icon(Icons.shield_outlined, color: accent), title: Text('Account & privacy', style: TextStyle(color: Colors.white)), subtitle: Text('For account access or privacy concerns, never include passwords or payment card details in a ticket.', style: TextStyle(color: Colors.white60))),
    ]),
  );
  Widget _sectionTitle(String text) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)));
  InputDecoration _decoration(String label) => InputDecoration(labelText: label, filled: true, fillColor: surface, labelStyle: const TextStyle(color: Colors.white60), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF343449))));
  Widget _field(TextEditingController c, String label, String hint, {int lines = 1}) => TextField(controller: c, maxLines: lines, maxLength: lines == 1 ? 160 : 12000, style: const TextStyle(color: Colors.white), decoration: _decoration(label).copyWith(hintText: hint, hintStyle: const TextStyle(color: Colors.white38)));
  Widget _status(String value) { final color = value == 'resolved' || value == 'closed' ? const Color(0xFF8FD9B5) : accent; return Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: .13), borderRadius: BorderRadius.circular(20)), child: Text(value.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))); }
}

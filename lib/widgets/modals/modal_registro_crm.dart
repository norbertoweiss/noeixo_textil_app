import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> mostrarModalCRM(
  BuildContext context, {
  required String clienteId,
  required String nomeCliente,
  required String representanteId,
}) async {
  String tipo = 'Visita Frustrada';
  TextEditingController obs = TextEditingController();

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => AlertDialog(
        title: Text(
          'CRM: $nomeCliente',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: tipo,
              decoration: const InputDecoration(
                labelText: 'Resultado da Visita',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Visita Frustrada',
                  child: Text('❌ Visita Frustrada (Ausente)'),
                ),
                DropdownMenuItem(
                  value: 'Visita Efetuada',
                  child: Text('✅ Visita de Relacionamento'),
                ),
                DropdownMenuItem(
                  value: 'Ligação / WhatsApp',
                  child: Text('📱 Contato Digital'),
                ),
              ],
              onChanged: (v) => setModalState(() => tipo = v!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: obs,
              decoration: const InputDecoration(
                labelText: 'Observações (Motivo, Próximo passo)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('clientes')
                  .doc(clienteId)
                  .collection('historico_crm')
                  .add({
                    'dataRegistro': FieldValue.serverTimestamp(),
                    'tipo': tipo,
                    'observacao': obs.text,
                    'representante': representanteId,
                  });
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ação gravada no CRM!')),
                );
              }
            },
            child: const Text('Gravar no Histórico'),
          ),
        ],
      ),
    ),
  );
}

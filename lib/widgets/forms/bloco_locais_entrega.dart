import 'package:flutter/material.dart';

class BlocoLocaisEntrega extends StatelessWidget {
  final bool isMesmoEndereco;
  final ValueChanged<bool> onChangedMesmoEndereco;
  final String ruaFiscal;
  final List<Map<String, dynamic>> locaisEntrega;
  final Function(List<Map<String, dynamic>>) onUpdateLocais;

  const BlocoLocaisEntrega({
    super.key,
    required this.isMesmoEndereco,
    required this.onChangedMesmoEndereco,
    required this.ruaFiscal,
    required this.locaisEntrega,
    required this.onUpdateLocais,
  });

  void _abrirModalEntrega(BuildContext context, {int? indexEdicao}) {
    final cepCtrl = TextEditingController();
    final ufCtrl = TextEditingController();
    final ruaCtrl = TextEditingController();
    final numCtrl = TextEditingController();
    final compCtrl = TextEditingController();
    final bairroCtrl = TextEditingController();
    final cidadeCtrl = TextEditingController();
    final instrucaoCtrl = TextEditingController();

    if (indexEdicao != null) {
      final item = locaisEntrega[indexEdicao];
      cepCtrl.text = item['cep'] ?? '';
      ufCtrl.text = item['uf'] ?? '';
      ruaCtrl.text = item['rua'] ?? '';
      numCtrl.text = item['numero'] ?? '';
      compCtrl.text = item['complemento'] ?? '';
      bairroCtrl.text = item['bairro'] ?? '';
      cidadeCtrl.text = item['cidade'] ?? '';
      instrucaoCtrl.text = item['instrucao'] ?? '';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          indexEdicao == null ? 'Adicionar Local de Entrega' : 'Editar Local',
          style: const TextStyle(fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: cepCtrl,
                      decoration: const InputDecoration(
                        labelText: 'CEP',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: ufCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Estado (UF)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: ruaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Rua / Logradouro',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: numCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nº',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: compCtrl,
                decoration: const InputDecoration(
                  labelText: 'Complemento (Doca, Loja 2)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: bairroCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Bairro',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: cidadeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Cidade',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: instrucaoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Instruções ao Motorista',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final novoLocal = {
                'cep': cepCtrl.text,
                'uf': ufCtrl.text,
                'rua': ruaCtrl.text,
                'numero': numCtrl.text,
                'complemento': compCtrl.text,
                'bairro': bairroCtrl.text,
                'cidade': cidadeCtrl.text,
                'instrucao': instrucaoCtrl.text,
                'ativo': indexEdicao == null
                    ? true
                    : (locaisEntrega[indexEdicao]['ativo'] ?? true),
              };

              List<Map<String, dynamic>> novaLista = List.from(locaisEntrega);
              if (indexEdicao == null) {
                novaLista.add(novoLocal);
              } else {
                novaLista[indexEdicao] = novoLocal;
              }

              onUpdateLocais(
                novaLista,
              ); // Devolve a lista atualizada para a tela principal
              Navigator.pop(context);
            },
            child: Text(
              indexEdicao == null ? 'Adicionar à Lista' : 'Salvar Alterações',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '2. Gestor de Filiais e Docas',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.teal,
          ),
        ),
        Card(
          elevation: 0,
          color: Colors.teal.shade50,
          child: SwitchListTile(
            title: const Text(
              'A Entrega é no mesmo endereço da Nota Fiscal?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              ruaFiscal.isEmpty ? 'Endereço não cadastrado' : ruaFiscal,
              style: const TextStyle(fontSize: 12),
            ),
            value: isMesmoEndereco,
            activeColor: Colors.teal,
            onChanged: onChangedMesmoEndereco,
          ),
        ),

        if (!isMesmoEndereco) ...[
          const SizedBox(height: 16),
          const Text(
            'Locais de Entrega Cadastrados:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (locaisEntrega.isEmpty)
            const Text(
              'Nenhum local adicionado. Clique no botão abaixo.',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),

          ...locaisEntrega.asMap().entries.map((entry) {
            int idx = entry.key;
            Map<String, dynamic> local = entry.value;
            bool isAtivo = local['ativo'] ?? true;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: isAtivo ? Colors.white : Colors.grey.shade200,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isAtivo ? Colors.teal : Colors.grey,
                  child: const Icon(
                    Icons.local_shipping,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(
                  '${local['rua']}, ${local['numero']} - ${local['cidade']}',
                  style: TextStyle(
                    decoration: isAtivo
                        ? TextDecoration.none
                        : TextDecoration.lineThrough,
                    color: isAtivo ? Colors.black : Colors.grey,
                  ),
                ),
                subtitle: Text(
                  'Comp: ${local['complemento']} | Ref: ${local['instrucao']}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: isAtivo,
                      activeColor: Colors.teal,
                      onChanged: (val) {
                        List<Map<String, dynamic>> novaLista = List.from(
                          locaisEntrega,
                        );
                        novaLista[idx]['ativo'] = val;
                        onUpdateLocais(novaLista);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueGrey),
                      onPressed: () =>
                          _abrirModalEntrega(context, indexEdicao: idx),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.teal,
              side: const BorderSide(color: Colors.teal),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.add),
            label: const Text(
              'Adicionar Novo Local de Entrega',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () => _abrirModalEntrega(context),
          ),
        ],
      ],
    );
  }
}

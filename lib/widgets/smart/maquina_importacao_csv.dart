import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================================
// INJEÇÃO DO GATILHO: MOTOR DE ROTEAMENTO
// ============================================================================
import 'motor_roteamento.dart';

class MaquinaImportacaoCSV extends StatefulWidget {
  final String empresaId;

  const MaquinaImportacaoCSV({super.key, required this.empresaId});

  @override
  State<MaquinaImportacaoCSV> createState() => _MaquinaImportacaoCSVState();
}

class _MaquinaImportacaoCSVState extends State<MaquinaImportacaoCSV> {
  bool _arquivoCarregado = false;
  String _nomeArquivo = '';
  int _totalLinhas = 0;
  List<String> _colunasDoExcelCliente = [];

  List<List<dynamic>> _dadosCsv = [];
  bool _importando = false;

  // ==========================================================================
  // LISTA DE CAMPOS ATUALIZADA (AGORA COM A INSCRIÇÃO ESTADUAL - IE)
  // ==========================================================================
  final List<Map<String, dynamic>> _camposNoEixo = [
    {'chave': 'cnpj', 'nome': 'CNPJ', 'obrigatorio': true},
    {'chave': 'ie', 'nome': 'Inscrição Estadual (IE)', 'obrigatorio': false},
    {'chave': 'razao_social', 'nome': 'Razão Social', 'obrigatorio': false},
    {'chave': 'nome_fantasia', 'nome': 'Nome Fantasia', 'obrigatorio': false},
    {
      'chave': 'contato_comprador',
      'nome': 'Nome do Contato (Comprador)',
      'obrigatorio': false,
    },
    {'chave': 'logradouro', 'nome': 'Logradouro / Rua', 'obrigatorio': false},
    {'chave': 'numero', 'nome': 'Número', 'obrigatorio': false},
    {
      'chave': 'complemento',
      'nome': 'Complemento (Sala, Galpão)',
      'obrigatorio': false,
    },
    {'chave': 'bairro', 'nome': 'Bairro', 'obrigatorio': false},
    {'chave': 'cep', 'nome': 'CEP Fiscal', 'obrigatorio': false},
    {'chave': 'cidade', 'nome': 'Cidade', 'obrigatorio': false},
    {'chave': 'estado', 'nome': 'UF (Estado)', 'obrigatorio': false},
    {'chave': 'whatsapp', 'nome': 'WhatsApp / Celular', 'obrigatorio': false},
    {
      'chave': 'telefone_fixo',
      'nome': 'Telefone Fixo (Empresa)',
      'obrigatorio': false,
    },
    {'chave': 'email', 'nome': 'E-mail Principal', 'obrigatorio': false},
  ];

  final Map<String, String?> _mapeamento = {};

  @override
  void initState() {
    super.initState();
    for (var campo in _camposNoEixo) {
      _mapeamento[campo['chave']] = null;
    }
  }

  Future<void> _selecionarArquivo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final stringData = utf8.decode(bytes, allowMalformed: true);

        List<List<dynamic>> csvTable = const CsvToListConverter(
          fieldDelimiter: ';',
          shouldParseNumbers: false,
        ).convert(stringData);

        if (csvTable.isNotEmpty && csvTable.first.length == 1) {
          csvTable = const CsvToListConverter(
            fieldDelimiter: ',',
            shouldParseNumbers: false,
          ).convert(stringData);
        }

        if (csvTable.isEmpty || csvTable.length < 2) {
          _mostrarAlerta(
            'Planilha Inválida',
            'O arquivo está vazio ou não possui dados para importar.',
          );
          return;
        }

        List<String> headers = csvTable.first
            .map((e) => e.toString().trim())
            .toList();

        setState(() {
          _dadosCsv = csvTable;
          _arquivoCarregado = true;
          _nomeArquivo = result.files.single.name;
          _totalLinhas = csvTable.length - 1;
          _colunasDoExcelCliente = ['Ignorar Coluna', ...headers];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Planilha carregada! Faça o mapeamento das colunas.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _mostrarAlerta(
        'Erro de Leitura',
        'Falha ao processar o arquivo. Verifique se é um CSV válido.\n$e',
      );
    }
  }

  Future<void> _executarImportacao() async {
    if (_mapeamento['cnpj'] == null ||
        _mapeamento['cnpj'] == 'Ignorar Coluna') {
      _mostrarAlerta(
        'Falta a Âncora Principal!',
        'Indique a coluna que contém o CNPJ para continuar.',
      );
      return;
    }

    setState(() => _importando = true);

    try {
      final headers = _colunasDoExcelCliente.sublist(1);
      int batchCount = 0;
      int totalImportados = 0;
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (int i = 1; i < _dadosCsv.length; i++) {
        var row = _dadosCsv[i];

        if (row.isEmpty) continue;

        String colunaCnpj = _mapeamento['cnpj']!;
        int indexCnpj = headers.indexOf(colunaCnpj);

        if (indexCnpj == -1 || indexCnpj >= row.length) continue;

        String valorCnpj = row[indexCnpj].toString().replaceAll(
          RegExp(r'[^0-9]'),
          '',
        );

        if (valorCnpj.isEmpty) continue;

        Map<String, dynamic> clienteData = {
          'empresa_id': widget.empresaId,
          'representante_id': 'Lista Clientes Importada',
          'ativo': true,
          'status_credito': 'Pendente Enriquecimento',
          'cnpj': valorCnpj,
          'data_importacao': FieldValue.serverTimestamp(),
        };

        for (var campo in _camposNoEixo) {
          String chave = campo['chave'];
          if (chave == 'cnpj') continue;

          String? colunaSelecionada = _mapeamento[chave];
          if (colunaSelecionada != null &&
              colunaSelecionada != 'Ignorar Coluna') {
            int index = headers.indexOf(colunaSelecionada);
            if (index != -1 && index < row.length) {
              clienteData[chave] = row[index].toString().trim();
            }
          }
        }

        DocumentReference docRef = FirebaseFirestore.instance
            .collection('clientes')
            .doc('${widget.empresaId}_$valorCnpj');
        batch.set(docRef, clienteData, SetOptions(merge: true));

        batchCount++;
        totalImportados++;

        if (batchCount == 400) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          batchCount = 0;
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      // =======================================================================
      // INJEÇÃO DO GATILHO AQUI: Roda logo após a importação ser concluída
      // =======================================================================
      await MotorRoteamento.sincronizarGeral();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'SUCESSO! $totalImportados clientes importados e distribuídos!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _mostrarAlerta('Erro de Banco de Dados', 'A importação falhou: $e');
    } finally {
      if (mounted) setState(() => _importando = false);
    }
  }

  void _mostrarAlerta(String titulo, String mensagem) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.schema, color: Colors.indigo, size: 32),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assistente de Importação Dinâmica',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      Text(
                        'Salve sua planilha Excel como ".csv" (UTF-8) e faça o upload abaixo.',
                        style: TextStyle(color: Colors.blueGrey),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _importando ? null : _selecionarArquivo,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Selecionar Planilha'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),

            const Divider(height: 30, thickness: 1.5),

            if (_arquivoCarregado) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Arquivo: $_nomeArquivo ($_totalLinhas clientes identificados)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

              const Text(
                'Ligue os pontos (De -> Para):',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.separated(
                    itemCount: _camposNoEixo.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      var campo = _camposNoEixo[index];
                      bool isObrigatorio = campo['obrigatorio'];

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  Text(
                                    campo['nome'],
                                    style: TextStyle(
                                      fontWeight: isObrigatorio
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  if (isObrigatorio)
                                    const Text(
                                      ' *',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward,
                              color: Colors.grey,
                              size: 16,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                hint: const Text('Selecione a coluna...'),
                                value: _mapeamento[campo['chave']],
                                items: _colunasDoExcelCliente.map((
                                  colunaExcel,
                                ) {
                                  return DropdownMenuItem(
                                    value: colunaExcel,
                                    child: Text(
                                      colunaExcel,
                                      style: TextStyle(
                                        color: colunaExcel == 'Ignorar Coluna'
                                            ? Colors.grey
                                            : Colors.black,
                                        fontSize: 13,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: _importando
                                    ? null
                                    : (valor) {
                                        setState(() {
                                          _mapeamento[campo['chave']] = valor;
                                        });
                                      },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _importando ? null : _executarImportacao,
                  icon: _importando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(
                    _importando
                        ? 'IMPORTANDO... AGUARDE'
                        : 'EXECUTAR IMPORTAÇÃO EM LOTE',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _importando
                        ? Colors.grey
                        : Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ] else ...[
              const Expanded(
                child: Center(
                  child: Text(
                    'Aguardando envio da planilha CSV...',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

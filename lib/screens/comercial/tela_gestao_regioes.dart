import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// DEPENDÊNCIAS DE CACHE DO MAPA
import 'package:path_provider/path_provider.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';

// ============================================================================
// INJEÇÃO DO GATILHO: MOTOR DE ROTEAMENTO
// ============================================================================
import '../../widgets/smart/motor_roteamento.dart';

// ============================================================================
// CACHE GLOBAL DE MAPAS (Evita bloqueio do OpenStreetMap e economiza dados)
// ============================================================================
CacheStore? _globalMapCacheStore;
bool _isInitializingCache = false;

Future<void> _initGlobalMapCache() async {
  if (_globalMapCacheStore != null || _isInitializingCache) return;
  _isInitializingCache = true;
  try {
    final dir = await getTemporaryDirectory();
    _globalMapCacheStore = HiveCacheStore(
      dir.path,
      hiveBoxName: 'noeixo_map_tiles_cache',
    );
  } catch (e) {
    debugPrint('Erro ao inicializar cache de mapas: $e');
  } finally {
    _isInitializingCache = false;
  }
}

// ============================================================================
// PALETA DE CORES DE ALTO CONTRASTE (Para destacar as regiões no Mapa Mestre)
// ============================================================================
final List<Color> _paletaCoresGlobais = [
  Colors.blue.shade700,
  Colors.red.shade700,
  Colors.green.shade700,
  Colors.orange.shade700,
  Colors.purple.shade700,
  Colors.teal.shade700,
  Colors.pink.shade700,
  Colors.amber.shade900,
  Colors.cyan.shade800,
  Colors.brown.shade700,
  Colors.indigo.shade700,
  Colors.lime.shade900,
];

Color _gerarCorEstrategica(String nome) {
  int index = nome.hashCode.abs() % _paletaCoresGlobais.length;
  return _paletaCoresGlobais[index];
}

class TelaGestaoRegioes extends StatefulWidget {
  const TelaGestaoRegioes({super.key});

  @override
  State<TelaGestaoRegioes> createState() => _TelaGestaoRegioesState();
}

class _TelaGestaoRegioesState extends State<TelaGestaoRegioes> {
  bool _mapaMestreExpandido = false;
  final MapController _masterMapController = MapController();

  // Memória Cache Blindada
  final Map<String, List<List<LatLng>>> _cachePoligonosIBGE = {};

  @override
  void initState() {
    super.initState();
    _initGlobalMapCache().then((_) {
      if (mounted) setState(() {});
    });
  }

  // Motor Assíncrono com Trava Anti-Loop
  Future<void> _fetchPoligonoIfMissing(String ibgeId) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://servicodados.ibge.gov.br/api/v3/malhas/municipios/$ibgeId?formato=application/vnd.geo+json',
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        if (features.isNotEmpty) {
          final geometry = features[0]['geometry'];
          final type = geometry['type'];
          final coordinates = geometry['coordinates'] as List;

          List<List<LatLng>> polygons = [];

          if (type == 'Polygon') {
            List<LatLng> pontos = coordinates[0]
                .map<LatLng>((c) => LatLng(c[1], c[0]))
                .toList();
            polygons.add(pontos);
          } else if (type == 'MultiPolygon') {
            for (var poly in coordinates) {
              List<LatLng> pontos = poly[0]
                  .map<LatLng>((c) => LatLng(c[1], c[0]))
                  .toList();
              polygons.add(pontos);
            }
          }
          if (mounted) {
            setState(() {
              _cachePoligonosIBGE[ibgeId] = polygons;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Erro Malha IBGE global: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _mapaMestreExpandido
          ? null
          : AppBar(
              title: const Text('Gestão de Territórios'),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('regioes_venda')
            .orderBy('nome')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma região de venda configurada.\nClique no + para criar o primeiro território.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          List<Polygon> poligonosAtuais = [];
          List<Marker> marcadoresAtuais = [];

          for (var doc in docs) {
            var data = doc.data() as Map<String, dynamic>;
            bool isAtivo = data['ativo'] ?? true;
            if (!isAtivo) continue;

            Color corRegiao = _gerarCorEstrategica(data['nome'] ?? '');
            List localidades = data['localidades'] ?? [];

            for (var loc in localidades) {
              if (loc['is_bairro'] == true &&
                  loc['lat'] != null &&
                  loc['lng'] != null) {
                marcadoresAtuais.add(
                  Marker(
                    point: LatLng(loc['lat'], loc['lng']),
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.maps_home_work,
                      color: corRegiao,
                      size: 30,
                    ),
                  ),
                );
              } else if (loc['ibge_id'] != null &&
                  loc['ibge_id'].toString().isNotEmpty) {
                String ibgeId = loc['ibge_id'].toString();

                if (_cachePoligonosIBGE.containsKey(ibgeId)) {
                  var poligonosDaCidade = _cachePoligonosIBGE[ibgeId]!;
                  for (var pts in poligonosDaCidade) {
                    poligonosAtuais.add(
                      Polygon(
                        points: pts,
                        color: corRegiao.withOpacity(0.5),
                        borderColor: corRegiao,
                        borderStrokeWidth: 2,
                        isFilled: true,
                      ),
                    );
                  }
                } else {
                  _cachePoligonosIBGE[ibgeId] = [];
                  _fetchPoligonoIfMissing(ibgeId);
                }
              }
            }
          }

          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _mapaMestreExpandido
                    ? MediaQuery.of(context).size.height
                    : 250,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _masterMapController,
                      options: const MapOptions(
                        initialCenter: LatLng(-26.4125, -49.0754),
                        initialZoom: 7.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.noeixo.app',
                          tileProvider: _globalMapCacheStore != null
                              ? CachedTileProvider(
                                  store: _globalMapCacheStore!,
                                  maxStale: const Duration(days: 30),
                                )
                              : null,
                        ),
                        PolygonLayer(polygons: poligonosAtuais),
                        MarkerLayer(markers: marcadoresAtuais),
                      ],
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: FloatingActionButton.small(
                        backgroundColor: Colors.white,
                        onPressed: () => setState(
                          () => _mapaMestreExpandido = !_mapaMestreExpandido,
                        ),
                        child: Icon(
                          _mapaMestreExpandido
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          color: Colors.indigo,
                        ),
                      ),
                    ),
                    if (!_mapaMestreExpandido)
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          color: Colors.black54,
                          child: const Text(
                            'MAPA MESTRE DE COBERTURA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              if (!_mapaMestreExpandido)
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var doc = docs[index];
                      var data = doc.data() as Map<String, dynamic>;
                      bool isAtivo = data['ativo'] ?? true;
                      Color cor = _gerarCorEstrategica(data['nome'] ?? '');

                      // Proteção de casting robusta para evitar quebra ao ler do Firebase
                      var rawPop = data['populacao_total'];
                      int popTotal = rawPop is double
                          ? rawPop.toInt()
                          : (rawPop as int? ?? 0);

                      var rawArea = data['area_total_km2'];
                      double areaTotal = rawArea is int
                          ? rawArea.toDouble()
                          : (rawArea as double? ?? 0.0);

                      List localidades = data['localidades'] ?? [];

                      return Card(
                        color: isAtivo ? Colors.white : Colors.grey.shade200,
                        elevation: isAtivo ? 2 : 0,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isAtivo ? cor : Colors.grey,
                            child: const Icon(Icons.map, color: Colors.white),
                          ),
                          title: Text(
                            data['nome'] ?? 'Sem Nome',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isAtivo ? Colors.black : Colors.grey,
                              decoration: isAtivo
                                  ? TextDecoration.none
                                  : TextDecoration.lineThrough,
                            ),
                          ),
                          subtitle: Text(
                            '${localidades.length} Cidades/Bairros | Pop: ${(popTotal / 1000).toStringAsFixed(1)}k hab. | Área: ${areaTotal.toStringAsFixed(0)} km²',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: isAtivo,
                                activeColor: Colors.teal,
                                onChanged: (val) async {
                                  await FirebaseFirestore.instance
                                      .collection('regioes_venda')
                                      .doc(doc.id)
                                      .update({'ativo': val});

                                  // Dispara o motor quando uma região é ativada/desativada
                                  await MotorRoteamento.sincronizarGeral();
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.indigo,
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TelaEdicaoRegiao(
                                      regiaoId: doc.id,
                                      dadosAtuais: data,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: _mapaMestreExpandido
          ? null
          : FloatingActionButton.extended(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Nova Região'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TelaEdicaoRegiao()),
              ),
            ),
    );
  }
}

// ============================================================================
// TELA DE CONSTRUÇÃO DO TERRITÓRIO
// ============================================================================
class TelaEdicaoRegiao extends StatefulWidget {
  final String? regiaoId;
  final Map<String, dynamic>? dadosAtuais;

  const TelaEdicaoRegiao({super.key, this.regiaoId, this.dadosAtuais});

  @override
  State<TelaEdicaoRegiao> createState() => _TelaEdicaoRegiaoState();
}

class _TelaEdicaoRegiaoState extends State<TelaEdicaoRegiao> {
  final _nomeCtrl = TextEditingController();
  List<Map<String, dynamic>> _localidades = [];
  bool _isLoading = false;

  List<Map<String, String>> _estados = [];
  String? _estadoSelecionado;
  List<Map<String, String>> _cidadesDoEstado = [];
  bool _carregandoCidades = false;

  TextEditingController? _autocompleteCtrl;
  String? _cidadeIdSelecionada;
  bool _restringirBairro = false;
  final _bairroCtrl = TextEditingController();

  bool _mapaExpandido = false;
  final MapController _mapController = MapController();
  List<Polygon> _poligonosRegiao = [];
  List<Marker> _marcadoresBairro = [];
  Color _corDaRegiao = Colors.indigo;

  @override
  void initState() {
    super.initState();

    _initGlobalMapCache().then((_) {
      if (mounted) setState(() {});
    });

    _buscarEstados();
    if (widget.dadosAtuais != null) {
      _nomeCtrl.text = widget.dadosAtuais!['nome'] ?? '';
      _atualizarCorDaRegiao();
      if (widget.dadosAtuais!['localidades'] != null) {
        _localidades = List<Map<String, dynamic>>.from(
          widget.dadosAtuais!['localidades'],
        );
        _reconstruirMapa();
      }
    }
    _nomeCtrl.addListener(_atualizarCorDaRegiao);
  }

  @override
  void dispose() {
    _nomeCtrl.removeListener(_atualizarCorDaRegiao);
    _nomeCtrl.dispose();
    super.dispose();
  }

  void _atualizarCorDaRegiao() {
    if (_nomeCtrl.text.isNotEmpty) {
      setState(() => _corDaRegiao = _gerarCorEstrategica(_nomeCtrl.text));
    }
  }

  Future<void> _buscarEstados() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://servicodados.ibge.gov.br/api/v1/localidades/estados?orderBy=nome',
        ),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        setState(
          () => _estados = data
              .map(
                (e) => {
                  'sigla': e['sigla'].toString(),
                  'nome': e['nome'].toString(),
                },
              )
              .toList(),
        );
      }
    } catch (e) {
      debugPrint('Erro IBGE Estados: $e');
    }
  }

  Future<void> _buscarCidades(String uf) async {
    setState(() {
      _carregandoCidades = true;
      _cidadesDoEstado.clear();
      _autocompleteCtrl?.clear();
      _cidadeIdSelecionada = null;
    });
    try {
      final response = await http.get(
        Uri.parse(
          'https://servicodados.ibge.gov.br/api/v1/localidades/estados/$uf/municipios?orderBy=nome',
        ),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        setState(
          () => _cidadesDoEstado = data
              .map(
                (c) => {'id': c['id'].toString(), 'nome': c['nome'].toString()},
              )
              .toList(),
        );
      }
    } catch (e) {
      debugPrint('Erro IBGE Cidades: $e');
    } finally {
      setState(() => _carregandoCidades = false);
    }
  }

  Future<LatLng?> _buscarCoordenadasCentro(String localidadeBusca) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$localidadeBusca, Brasil&format=json&limit=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'NoEixoTextilApp/1.0'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isNotEmpty) {
          return LatLng(
            double.parse(data[0]['lat']),
            double.parse(data[0]['lon']),
          );
        }
      }
    } catch (e) {
      debugPrint('Erro no Radar Cartográfico: $e');
    }
    return null;
  }

  // ============================================================================
  // MOTOR DE CÁLCULO REAL - COM BLINDAGEM DE FORMATO (, vs .) E ANOS EM CASCATA
  // ============================================================================

  Future<int> _buscarPopulacaoRealIBGE(String ibgeId) async {
    try {
      final url = Uri.parse(
        'https://servicodados.ibge.gov.br/api/v3/agregados/4709/periodos/2022/variaveis/93?localidades=N6[$ibgeId]',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isNotEmpty &&
            data[0]['resultados'] != null &&
            data[0]['resultados'].isNotEmpty) {
          final series = data[0]['resultados'][0]['series'];
          if (series.isNotEmpty && series[0]['serie'] != null) {
            var valores = series[0]['serie'].values;
            if (valores.isNotEmpty &&
                valores.first != null &&
                valores.first.toString() != '-') {
              String popStr = valores.first.toString().replaceAll(',', '.');
              return double.parse(popStr).toInt();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar Censo IBGE SIDRA: $e');
    }
    return 0;
  }

  Future<double> _buscarAreaRealIBGE(String ibgeId) async {
    // 1. TENTA CASCATA DE ANOS NO AGREGADO 1301 (Algumas cidades falham no ano corrente)
    List<String> periodosTentativa = [
      '2022',
      '2021',
      '2020',
      '2019',
      '2018',
      '-1',
    ];

    for (String periodo in periodosTentativa) {
      try {
        final url = Uri.parse(
          'https://servicodados.ibge.gov.br/api/v3/agregados/1301/periodos/$periodo/variaveis/61?localidades=N6[$ibgeId]',
        );
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data.isNotEmpty &&
              data[0]['resultados'] != null &&
              data[0]['resultados'].isNotEmpty) {
            final series = data[0]['resultados'][0]['series'];
            if (series.isNotEmpty && series[0]['serie'] != null) {
              var valores = series[0]['serie'].values;
              if (valores.isNotEmpty && valores.first != null) {
                String valorOriginal = valores.first.toString();

                // Pula o ciclo se o IBGE enviar dados omitidos
                if (valorOriginal.trim() == '-' ||
                    valorOriginal.trim() == '...')
                  continue;

                // Limpeza agressiva: Exemplo "1.404,20" vira "1404.20"
                String areaStr = valorOriginal.replaceAll(
                  RegExp(r'[^0-9\,\.]'),
                  '',
                );
                if (areaStr.contains('.') && areaStr.contains(',')) {
                  areaStr = areaStr.replaceAll('.', '');
                  areaStr = areaStr.replaceAll(',', '.');
                } else if (areaStr.contains(',')) {
                  areaStr = areaStr.replaceAll(',', '.');
                }

                double? areaCalculada = double.tryParse(areaStr);
                if (areaCalculada != null && areaCalculada > 0)
                  return areaCalculada;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Erro Área IBGE ($periodo): $e');
      }
    }

    // 2. BACKUP: SE FALHAR, PUXA PELOS METADADOS DA MALHA (Mais estável mas menos documentado)
    try {
      final urlMeta = Uri.parse(
        'https://servicodados.ibge.gov.br/api/v3/malhas/municipios/$ibgeId/metadados',
      );
      final responseMeta = await http.get(urlMeta);
      if (responseMeta.statusCode == 200) {
        final data = json.decode(responseMeta.body);
        if (data.isNotEmpty && data[0]['area'] != null) {
          var areaMetadado = data[0]['area'];
          if (areaMetadado is Map && areaMetadado['dimensao'] != null) {
            return double.tryParse(areaMetadado['dimensao'].toString()) ?? 0.0;
          } else {
            return double.tryParse(areaMetadado.toString()) ?? 0.0;
          }
        }
      }
    } catch (e) {
      debugPrint('Erro Backup Metadados Área: $e');
    }

    return 0.0; // Falha segura
  }

  Future<void> _buscarEDesenharPoligonoIBGE(String ibgeId) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://servicodados.ibge.gov.br/api/v3/malhas/municipios/$ibgeId?formato=application/vnd.geo+json',
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        if (features.isNotEmpty) {
          final geometry = features[0]['geometry'];
          final type = geometry['type'];
          final coordinates = geometry['coordinates'] as List;

          List<Polygon> novos = [];
          if (type == 'Polygon') {
            List<LatLng> pontos = coordinates[0]
                .map<LatLng>((c) => LatLng(c[1], c[0]))
                .toList();
            novos.add(
              Polygon(
                points: pontos,
                color: _corDaRegiao.withOpacity(0.5),
                borderColor: _corDaRegiao,
                borderStrokeWidth: 2,
                isFilled: true,
              ),
            );
          } else if (type == 'MultiPolygon') {
            for (var poly in coordinates) {
              List<LatLng> pontos = poly[0]
                  .map<LatLng>((c) => LatLng(c[1], c[0]))
                  .toList();
              novos.add(
                Polygon(
                  points: pontos,
                  color: _corDaRegiao.withOpacity(0.5),
                  borderColor: _corDaRegiao,
                  borderStrokeWidth: 2,
                  isFilled: true,
                ),
              );
            }
          }
          setState(() => _poligonosRegiao.addAll(novos));
          if (novos.isNotEmpty) {
            _mapController.move(novos.first.points.first, 9.0);
          }
        }
      }
    } catch (e) {
      debugPrint('Erro Malha IBGE: $e');
    }
  }

  Future<void> _reconstruirMapa() async {
    _poligonosRegiao.clear();
    _marcadoresBairro.clear();
    for (var loc in _localidades) {
      if (loc['ibge_id'] != null &&
          loc['ibge_id'].toString().isNotEmpty &&
          loc['is_bairro'] != true) {
        await _buscarEDesenharPoligonoIBGE(loc['ibge_id'].toString());
      } else if (loc['lat'] != null && loc['lng'] != null) {
        _marcadoresBairro.add(
          Marker(
            point: LatLng(loc['lat'], loc['lng']),
            width: 40,
            height: 40,
            child: const Icon(
              Icons.maps_home_work,
              color: Colors.orange,
              size: 40,
            ),
          ),
        );
      }
    }
  }

  Future<void> _adicionarLocalidade(String nomeCidade) async {
    if (nomeCidade.trim().isEmpty || _cidadeIdSelecionada == null) return;

    if (_nomeCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, defina o nome da Região primeiro.'),
        ),
      );
      return;
    }

    if (_restringirBairro && _bairroCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Digite o nome do bairro!')));
      return;
    }

    String baseCityStr = '$nomeCidade - $_estadoSelecionado';
    bool isTentandoInteira = !_restringirBairro;
    String nomeCompleto = isTentandoInteira
        ? baseCityStr
        : '$baseCityStr [Bairro: ${_bairroCtrl.text.trim()}]';

    if (_localidades.any((l) => l['nome'] == nomeCompleto)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta localidade já está na lista atual!'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final query = await FirebaseFirestore.instance
          .collection('regioes_venda')
          .where('ativo', isEqualTo: true)
          .get();
      String? regiaoConflito;

      for (var doc in query.docs) {
        if (widget.regiaoId != null && doc.id == widget.regiaoId) continue;
        var data = doc.data();
        List locs = data['localidades'] ?? [];

        for (var loc in locs) {
          String locName = loc['nome'];
          if (isTentandoInteira) {
            if (locName.startsWith(baseCityStr)) {
              regiaoConflito = data['nome'];
              break;
            }
          } else {
            if (locName == baseCityStr) {
              regiaoConflito =
                  "${data['nome']} (Eles dominam a cidade inteira)";
              break;
            }
            if (locName == nomeCompleto) {
              regiaoConflito = data['nome'];
              break;
            }
          }
        }
        if (regiaoConflito != null) break;
      }

      if (regiaoConflito != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ Bloqueado: Conflito comercial com a região "$regiaoConflito".',
              ),
              backgroundColor: Colors.red.shade800,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      String idIbgeSalvo = _cidadeIdSelecionada!;

      int populacaoCalculada = 0;
      double areaCalculada = 0.0;

      int popCidadeReal = await _buscarPopulacaoRealIBGE(idIbgeSalvo);
      double areaCidadeReal = await _buscarAreaRealIBGE(idIbgeSalvo);

      if (isTentandoInteira) {
        populacaoCalculada = popCidadeReal;
        areaCalculada = areaCidadeReal;
      } else {
        populacaoCalculada = (popCidadeReal * 0.15).toInt();
        areaCalculada = areaCidadeReal * 0.10;
      }

      LatLng? coordCentro;
      if (!isTentandoInteira) {
        coordCentro = await _buscarCoordenadasCentro(
          '${_bairroCtrl.text.trim()}, $nomeCidade, $_estadoSelecionado',
        );
      }

      setState(() {
        _localidades.insert(0, {
          'nome': nomeCompleto,
          'populacao': populacaoCalculada,
          'area_km2': areaCalculada,
          'ibge_id': idIbgeSalvo,
          'is_bairro': !isTentandoInteira,
          'lat': coordCentro?.latitude,
          'lng': coordCentro?.longitude,
        });

        _bairroCtrl.clear();
        _autocompleteCtrl?.clear();
        _cidadeIdSelecionada = null;
      });

      if (isTentandoInteira) {
        await _buscarEDesenharPoligonoIBGE(idIbgeSalvo);
      } else if (coordCentro != null) {
        setState(() {
          _marcadoresBairro.add(
            Marker(
              point: coordCentro!,
              width: 40,
              height: 40,
              child: const Icon(
                Icons.maps_home_work,
                color: Colors.orange,
                size: 40,
              ),
            ),
          );
        });
        _mapController.move(coordCentro!, 12.0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro na validação: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // A Mágica Matemática Segura: Proteção contra tipagem mista do Firebase (int vs double)
  int get _populacaoTotal => _localidades.fold(0, (sum, item) {
    var val = item['populacao'];
    if (val == null) return sum;
    int numVal = val is double ? val.toInt() : val as int;
    return sum + numVal;
  });

  double get _areaTotal => _localidades.fold(0.0, (sum, item) {
    var val = item['area_km2'];
    if (val == null) return sum;
    double numVal = val is int ? val.toDouble() : val as double;
    return sum + numVal;
  });

  Future<void> _salvarRegiao() async {
    if (_nomeCtrl.text.isEmpty || _localidades.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dê um nome à região e adicione localidades.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    Map<String, dynamic> dados = {
      'nome': _nomeCtrl.text,
      'localidades': _localidades,
      'populacao_total': _populacaoTotal,
      'area_total_km2': _areaTotal,
      'ativo': widget.dadosAtuais?['ativo'] ?? true,
      'ultima_atualizacao': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.regiaoId == null) {
        await FirebaseFirestore.instance.collection('regioes_venda').add(dados);
      } else {
        await FirebaseFirestore.instance
            .collection('regioes_venda')
            .doc(widget.regiaoId)
            .update(dados);
      }

      // =======================================================================
      // INJEÇÃO DA IGNIÇÃO AQUI: Executa a sincronização após salvar a região
      // =======================================================================
      await MotorRoteamento.sincronizarGeral();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Território salvo com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget mapaVisual = Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(-26.4125, -49.0754),
                initialZoom: 7.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.noeixo.app',
                  tileProvider: _globalMapCacheStore != null
                      ? CachedTileProvider(
                          store: _globalMapCacheStore!,
                          maxStale: const Duration(days: 30),
                        )
                      : null,
                ),
                PolygonLayer(polygons: _poligonosRegiao),
                MarkerLayer(markers: _marcadoresBairro),
              ],
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: FloatingActionButton.small(
              backgroundColor: Colors.white,
              onPressed: () {
                setState(() => _mapaExpandido = !_mapaExpandido);
                if (_mapaExpandido) FocusScope.of(context).unfocus();
              },
              child: Icon(
                _mapaExpandido ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: _mapaExpandido
          ? null
          : AppBar(
              title: Text(
                widget.regiaoId == null
                    ? 'Construtor de Região'
                    : 'Editar Região',
              ),
            ),
      body: Column(
        children: [
          if (!_mapaExpandido) ...[
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blueGrey.shade900,
              child: Column(
                children: [
                  TextField(
                    controller: _nomeCtrl,
                    style: TextStyle(
                      color: _corDaRegiao.withAlpha(200),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Nome da Região',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _blocoEstatistica(
                        'População',
                        '${(_populacaoTotal / 1000).toStringAsFixed(1)}k',
                        Icons.groups,
                      ),
                      _blocoEstatistica(
                        'Área (km²)',
                        _areaTotal.toStringAsFixed(0),
                        Icons.map,
                      ),
                      _blocoEstatistica(
                        'Densidade',
                        _areaTotal > 0
                            ? (_populacaoTotal / _areaTotal).toStringAsFixed(1)
                            : '0',
                        Icons.analytics,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.blueGrey.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Adicionar ao Território:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Estado',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          value: _estadoSelecionado,
                          items: _estados
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e['sigla'],
                                  child: Text(e['sigla']!),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setState(() => _estadoSelecionado = val);
                            if (val != null) _buscarCidades(val);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            _carregandoCidades
                                ? const Center(child: LinearProgressIndicator())
                                : Autocomplete<String>(
                                    optionsBuilder: (tv) => _cidadesDoEstado
                                        .map((e) => e['nome']!)
                                        .where(
                                          (n) => n.toLowerCase().contains(
                                            tv.text.toLowerCase(),
                                          ),
                                        ),
                                    onSelected: (n) {
                                      _autocompleteCtrl?.text = n;
                                      _cidadeIdSelecionada = _cidadesDoEstado
                                          .firstWhere(
                                            (e) => e['nome'] == n,
                                          )['id'];
                                    },
                                    fieldViewBuilder: (ctx, ctrl, fn, oec) {
                                      _autocompleteCtrl = ctrl;
                                      return TextField(
                                        controller: ctrl,
                                        focusNode: fn,
                                        onEditingComplete: oec,
                                        decoration: InputDecoration(
                                          labelText: _estadoSelecionado == null
                                              ? 'Selecione o Estado'
                                              : 'Digite a Cidade',
                                          border: const OutlineInputBorder(),
                                          filled: true,
                                          fillColor: _estadoSelecionado == null
                                              ? Colors.grey.shade200
                                              : Colors.white,
                                          prefixIcon: const Icon(Icons.search),
                                        ),
                                        enabled: _estadoSelecionado != null,
                                      );
                                    },
                                  ),
                            if (_estadoSelecionado != null) ...[
                              CheckboxListTile(
                                title: const Text(
                                  'Limitar a Bairro Específico',
                                  style: TextStyle(fontSize: 12),
                                ),
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                value: _restringirBairro,
                                onChanged: (val) {
                                  setState(() {
                                    _restringirBairro = val!;
                                  });
                                },
                              ),
                              if (_restringirBairro)
                                TextField(
                                  controller: _bairroCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Nome do Bairro',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                    prefixIcon: Icon(Icons.maps_home_work),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          if (_autocompleteCtrl != null &&
                              _autocompleteCtrl!.text.isNotEmpty) {
                            await _adicionarLocalidade(_autocompleteCtrl!.text);
                          }
                        },
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add, size: 24),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          Expanded(
            child: _mapaExpandido
                ? Padding(padding: const EdgeInsets.all(8), child: mapaVisual)
                : Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: _localidades.length,
                          itemBuilder: (ctx, idx) {
                            var loc = _localidades[idx];
                            bool isBairro = loc['is_bairro'] == true;
                            return Card(
                              child: ListTile(
                                leading: Icon(
                                  isBairro
                                      ? Icons.maps_home_work
                                      : Icons.location_city,
                                  color: isBairro
                                      ? Colors.orange
                                      : _corDaRegiao,
                                ),
                                title: Text(
                                  loc['nome'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  'População: ${(loc['populacao'] ?? 0).toString()} hab. | Área: ${(loc['area_km2'] ?? 0).toStringAsFixed(0)} km²',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _localidades.removeAt(idx);
                                      _reconstruirMapa();
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: mapaVisual,
                        ),
                      ),
                    ],
                  ),
          ),

          if (!_mapaExpandido)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                icon: const Icon(Icons.save),
                label: const Text(
                  'SALVAR TERRITÓRIO',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onPressed: _salvarRegiao,
              ),
            ),
        ],
      ),
    );
  }

  Widget _blocoEstatistica(String t, String v, IconData i) {
    return Column(
      children: [
        Icon(i, color: Colors.tealAccent, size: 24),
        const SizedBox(height: 4),
        Text(
          v,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(t, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}

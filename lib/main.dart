import 'package:flutter/material.dart';
import 'package:mysql1/mysql1.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gráficos com Flutter',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MainPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Classe para gerenciar a conexão com o banco de dados
class DatabaseHelper {
  static ConnectionSettings? _settings;

  static void configure({
    required String host,
    required int port,
    required String user,
    required String password,
    required String db,
  }) {
    _settings = ConnectionSettings(
      host: host,
      port: port,
      user: user,
      password: password,
      db: db,
    );
  }

  static ConnectionSettings? get currentSettings => _settings;

  static bool get isConfigured => _settings != null;

  static Future<MySqlConnection?> getConnection() async {
    if (_settings == null) {
      throw Exception('Configuração do banco de dados não foi definida');
    }

    try {
      return await MySqlConnection.connect(_settings!);
    } catch (e) {
      print('Erro ao conectar com o banco: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchProdutos({
    String? dataFiltro,
    String? corFiltro,
  }) async {
    MySqlConnection? conn = await getConnection();
    if (conn == null) {
      throw Exception('Não foi possível conectar ao banco de dados');
    }

    try {
      String query = '''
        SELECT p.id_prod, c.cor, m.material, t.tamanho, p.data_hora
        FROM tb_prod p
        JOIN tb_cor c ON p.cor = c.id_cor
        JOIN tb_material m ON p.material = m.id_material
        JOIN tb_tamanho t ON p.tamanho = t.id_tamanho
      ''';

      List<String> conditions = [];
      List<dynamic> parameters = [];

      if (dataFiltro != null && dataFiltro.isNotEmpty) {
        conditions.add('DATE(p.data_hora) = ?');
        parameters.add(dataFiltro);
      }

      if (corFiltro != null && corFiltro.isNotEmpty) {
        conditions.add('c.cor = ?');
        parameters.add(corFiltro);
      }

      if (conditions.isNotEmpty) {
        query += ' WHERE ${conditions.join(' AND ')}';
      }

      print('Executando query: $query');
      print('Parâmetros: $parameters');

      Results results = await conn.query(query, parameters);

      List<Map<String, dynamic>> produtos = [];
      for (var row in results) {
        produtos.add({
          'id_prod': row['id_prod'],
          'cor': row['cor'],
          'material': row['material'],
          'tamanho': row['tamanho'],
          'data_hora': row['data_hora']?.toString() ?? '',
        });
      }

      print('Produtos encontrados: ${produtos.length}');
      return produtos;
    } catch (e) {
      print('Erro na consulta: $e');
      throw Exception('Erro ao consultar produtos: $e');
    } finally {
      await conn.close();
    }
  }

  static Future<bool> testConnection() async {
    MySqlConnection? conn = await getConnection();
    if (conn != null) {
      await conn.close();
      return true;
    }
    return false;
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  String? selectedDate;
  String? selectedColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          FilterPage(
            onFiltersChanged: (date, color) {
              setState(() {
                selectedDate = date;
                selectedColor = color;
              });
            },
            onNavigateToCharts: () {
              setState(() {
                _currentIndex = 1;
              });
            },
          ),
          ChartsPage(selectedDate: selectedDate, selectedColor: selectedColor),
          AboutPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        fixedColor: Colors.blue,
        backgroundColor: Colors.grey[50],
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.filter_list),
            label: 'Filtros',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Gráficos',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: 'Sobre'),
        ],
      ),
    );
  }
}

class FilterPage extends StatefulWidget {
  final Function(String?, String?) onFiltersChanged;
  final VoidCallback onNavigateToCharts;

  const FilterPage({
    super.key,
    required this.onFiltersChanged,
    required this.onNavigateToCharts,
  });

  @override
  _FilterPageState createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  final TextEditingController dateController = TextEditingController();
  final TextEditingController colorController = TextEditingController();

  // Controladores para configuração do banco
  final TextEditingController hostController = TextEditingController(
    text: '192.168.18.13',
  );
  final TextEditingController portController = TextEditingController(
    text: '3306',
  );
  final TextEditingController userController = TextEditingController(
    text: 'root',
  );
  final TextEditingController passwordController = TextEditingController(
    text: 'root',
  );
  final TextEditingController dbController = TextEditingController(
    text: 'db_prod',
  );

  String? selectedDate;
  String? selectedColor;
  bool _testingConnection = false;
  String? _connectionStatus;
  bool _showDatabaseConfig = false;

  @override
  void initState() {
    super.initState();
    // Aplicar configuração padrão se não houver nenhuma
    if (!DatabaseHelper.isConfigured) {
      _applyDatabaseConfig();
    } else {
      // Carregar configuração atual
      _loadCurrentConfig();
    }
  }

  void _loadCurrentConfig() {
    final settings = DatabaseHelper.currentSettings;
    if (settings != null) {
      hostController.text = settings.host;
      portController.text = settings.port.toString();
      userController.text = settings.user!;
      passwordController.text = settings.password ?? '';
      dbController.text = settings.db!;
    }
  }

  void _applyDatabaseConfig() {
    try {
      int port = int.parse(portController.text);
      DatabaseHelper.configure(
        host: hostController.text,
        port: port,
        user: userController.text,
        password: passwordController.text,
        db: dbController.text,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Configuração do banco aplicada com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _showDatabaseConfig = false;
        _connectionStatus = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro na configuração: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testDatabaseConnection() async {
    if (!DatabaseHelper.isConfigured) {
      setState(() {
        _connectionStatus = 'Configure o banco de dados primeiro ⚠️';
      });
      return;
    }

    setState(() {
      _testingConnection = true;
      _connectionStatus = null;
    });

    try {
      bool connected = await DatabaseHelper.testConnection();
      setState(() {
        _connectionStatus =
            connected
                ? 'Conexão com banco de dados OK! ✅'
                : 'Falha na conexão com banco de dados ❌';
      });
    } catch (e) {
      setState(() {
        _connectionStatus = 'Erro: $e ❌';
      });
    } finally {
      setState(() {
        _testingConnection = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Filtros e Configurações'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              setState(() {
                _showDatabaseConfig = !_showDatabaseConfig;
              });
            },
            tooltip: 'Configurar Banco',
          ),
          IconButton(
            icon: Icon(Icons.wifi_tethering),
            onPressed: _testDatabaseConnection,
            tooltip: 'Testar Conexão',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Configuração do Banco de Dados
              if (_showDatabaseConfig)
                Card(
                  elevation: 4,
                  color: Colors.orange[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.storage, color: Colors.orange[800]),
                            SizedBox(width: 8),
                            Text(
                              'Configuração do Banco de Dados',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[800],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: hostController,
                          decoration: InputDecoration(
                            labelText: 'Host/IP do Servidor',
                            hintText: 'Ex: 192.168.1.100',
                            prefixIcon: Icon(Icons.computer),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        TextField(
                          controller: portController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Porta',
                            hintText: 'Ex: 3306',
                            prefixIcon: Icon(Icons.power_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        TextField(
                          controller: userController,
                          decoration: InputDecoration(
                            labelText: 'Usuário',
                            hintText: 'Ex: root',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        TextField(
                          controller: dbController,
                          decoration: InputDecoration(
                            labelText: 'Nome do Banco',
                            hintText: 'Ex: db_prod',
                            prefixIcon: Icon(
                              Icons.miscellaneous_services_rounded,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _applyDatabaseConfig,
                                icon: Icon(Icons.save),
                                label: Text('Aplicar Configuração'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _showDatabaseConfig = false;
                                });
                              },
                              child: Icon(Icons.close),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              if (_showDatabaseConfig) SizedBox(height: 16),

              // Status da conexão
              if (_testingConnection || _connectionStatus != null)
                Card(
                  color:
                      _connectionStatus?.contains('OK') == true
                          ? Colors.green[50]
                          : _connectionStatus?.contains('⚠️') == true
                          ? Colors.orange[50]
                          : Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        if (_testingConnection)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _testingConnection
                                ? 'Testando conexão...'
                                : _connectionStatus ?? '',
                            style: TextStyle(
                              color:
                                  _connectionStatus?.contains('OK') == true
                                      ? Colors.green[800]
                                      : _connectionStatus?.contains('⚠️') ==
                                          true
                                      ? Colors.orange[800]
                                      : Colors.red[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (_connectionStatus != null) SizedBox(height: 16),

              // Status da configuração atual
              Card(
                color:
                    DatabaseHelper.isConfigured
                        ? Colors.blue[50]
                        : Colors.grey[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            DatabaseHelper.isConfigured
                                ? Icons.check_circle
                                : Icons.warning,
                            color:
                                DatabaseHelper.isConfigured
                                    ? Colors.blue
                                    : Colors.orange,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Status da Configuração',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  DatabaseHelper.isConfigured
                                      ? Colors.blue[800]
                                      : Colors.orange[800],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      if (DatabaseHelper.isConfigured) ...[
                        Text('✅ Banco configurado'),
                        Text('Host: ${DatabaseHelper.currentSettings?.host}'),
                        Text('Banco: ${DatabaseHelper.currentSettings?.db}'),
                      ] else ...[
                        Text(
                          '⚠️ Configure o banco de dados antes de continuar',
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Filtros de Dados
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filtros de Produtos',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: dateController,
                        decoration: InputDecoration(
                          labelText: 'Data (YYYY-MM-DD)',
                          hintText: 'Ex: 2024-01-15',
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (value) {
                          selectedDate = value.isEmpty ? null : value;
                        },
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: colorController,
                        decoration: InputDecoration(
                          labelText: 'Cor',
                          hintText: 'Ex: Azul, Vermelho, Verde',
                          prefixIcon: Icon(Icons.color_lens),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (value) {
                          selectedColor = value.isEmpty ? null : value;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed:
                    DatabaseHelper.isConfigured
                        ? () {
                          widget.onFiltersChanged(selectedDate, selectedColor);
                          widget.onNavigateToCharts();
                        }
                        : null,
                icon: Icon(Icons.search),
                label: Text('Aplicar Filtros e Ver Gráfico'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  backgroundColor:
                      DatabaseHelper.isConfigured ? Colors.blue : Colors.grey,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  dateController.clear();
                  colorController.clear();
                  selectedDate = null;
                  selectedColor = null;
                  widget.onFiltersChanged(null, null);
                },
                icon: Icon(Icons.clear),
                label: Text('Limpar Filtros'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.grey[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Icon(Icons.info, color: Colors.blue),
                      SizedBox(height: 8),
                      Text(
                        'Dicas:\n• Configure o banco de dados primeiro\n• Teste a conexão antes de aplicar filtros\n• Você pode filtrar por data, cor ou ambos\n• Deixe em branco para ver todos os produtos',
                        style: TextStyle(color: Colors.blue[800]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChartsPage extends StatefulWidget {
  final String? selectedDate;
  final String? selectedColor;

  const ChartsPage({super.key, this.selectedDate, this.selectedColor});

  @override
  _ChartsPageState createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> {
  Future<List<Map<String, dynamic>>> fetchProdutos() async {
    try {
      return await DatabaseHelper.fetchProdutos(
        dataFiltro: widget.selectedDate,
        corFiltro: widget.selectedColor,
      );
    } catch (e) {
      print('Erro ao buscar produtos: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gráficos de Produtos'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body:
          !DatabaseHelper.isConfigured
              ? Center(
                child: Card(
                  color: Colors.orange[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.settings, size: 48, color: Colors.orange),
                        SizedBox(height: 8),
                        Text(
                          'Configure o Banco de Dados',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Vá para a aba Filtros e configure a conexão com o banco de dados primeiro.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.orange[700]),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Mostrar filtros ativos
                    if (widget.selectedDate != null ||
                        widget.selectedColor != null)
                      Card(
                        color: Colors.blue[50],
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Filtros Aplicados:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                ),
                              ),
                              if (widget.selectedDate != null)
                                Text('• Data: ${widget.selectedDate}'),
                              if (widget.selectedColor != null)
                                Text('• Cor: ${widget.selectedColor}'),
                            ],
                          ),
                        ),
                      ),
                    SizedBox(height: 16),
                    Expanded(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: fetchProdutos(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Carregando dados do banco...'),
                                ],
                              ),
                            );
                          } else if (snapshot.hasError) {
                            return Center(
                              child: Card(
                                color: Colors.red[50],
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.error,
                                        color: Colors.red,
                                        size: 48,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Erro ao carregar dados',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red[800],
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        '${snapshot.error}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.red[700],
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: () {
                                          setState(() {});
                                        },
                                        child: Text('Tentar Novamente'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          } else if (!snapshot.hasData ||
                              snapshot.data!.isEmpty) {
                            return Center(
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.inbox,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Nenhum produto encontrado',
                                        style: TextStyle(fontSize: 18),
                                      ),
                                      Text(
                                        'Tente ajustar os filtros',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          } else {
                            List<Map<String, dynamic>> produtos =
                                snapshot.data!;

                            // Contar produtos por cor
                            Map<String, int> colorCount = {};
                            for (var produto in produtos) {
                              String cor = produto['cor'] ?? 'Sem cor';
                              colorCount[cor] = (colorCount[cor] ?? 0) + 1;
                            }

                            // Criar dados para o gráfico
                            List<BarChartGroupData> barGroups = [];
                            int index = 0;
                            colorCount.entries.forEach((entry) {
                              barGroups.add(
                                BarChartGroupData(
                                  x: index,
                                  barRods: [
                                    BarChartRodData(
                                      toY: entry.value.toDouble(),
                                      color: _getColorForName(entry.key),
                                      width: 20,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                ),
                              );
                              index++;
                            });

                            return Column(
                              children: [
                                Text(
                                  'Produtos por Cor (${produtos.length} total)',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Expanded(
                                  child: BarChart(
                                    BarChartData(
                                      backgroundColor: Colors.grey[200],
                                      barGroups: barGroups,
                                      titlesData: FlTitlesData(
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 40,
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 40,
                                            getTitlesWidget: (value, meta) {
                                              if (value.toInt() <
                                                  colorCount.keys.length) {
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 8.0,
                                                      ),
                                                  child: Text(
                                                    colorCount.keys.elementAt(
                                                      value.toInt(),
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                );
                                              }
                                              return Text('');
                                            },
                                          ),
                                        ),
                                        topTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        rightTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                      ),
                                      borderData: FlBorderData(show: true),
                                      gridData: FlGridData(show: true),
                                      maxY:
                                          colorCount.values.isNotEmpty
                                              ? colorCount.values
                                                      .reduce(
                                                        (a, b) => a > b ? a : b,
                                                      )
                                                      .toDouble() +
                                                  1
                                              : 10,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16),
                                // Lista detalhada
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Total de peças, por cor:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        ...colorCount.entries
                                            .map(
                                              (entry) => Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 2.0,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 16,
                                                      height: 16,
                                                      decoration: BoxDecoration(
                                                        color: _getColorForName(
                                                          entry.key,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              2,
                                                            ),
                                                      ),
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      '${entry.key}: ${entry.value} produtos',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Color _getColorForName(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'azul':
        return Colors.blue;
      case 'vermelho':
        return Colors.red;
      case 'verde':
        return Colors.green;
      case 'amarelo':
        return Colors.yellow;
      case 'roxo':
        return Colors.purple;
      case 'laranja':
        return Colors.orange;
      case 'rosa':
        return Colors.pink;
      case 'preto':
        return Colors.black;
      case 'branco':
        return Colors.grey[300]!;
      case 'cinza':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sobre'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Icon(Icons.storage, size: 80, color: Colors.blue)),
            SizedBox(height: 20),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gráficos de Produtos',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Versão 1.2 - Configuração Dinâmica MySQL',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Aplicação feita com Flutter para vizualização de dados, e um banco de dados MySQL para armazenamento de dados de peças produzidas.',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'App feito por: Lucas Soares Pevarello e Marcelo Soares Pevarello, com apoio dos professores Alex Pisciotta, Márcio Nagy e Orlando Rosa Junior',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Funcionalidades',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildFeatureItem(
                      '🗄️',
                      'Banco de dados MySQL configurável',
                    ),
                    _buildFeatureItem('⚙️', 'Configuração dinâmica de conexão'),
                    _buildFeatureItem('📊', 'Gráficos de barras'),
                    _buildFeatureItem('🔍', 'Filtros por data e cor'),
                    _buildFeatureItem('📱', 'Interface simples e responsiva'),
                    _buildFeatureItem('🔄', 'Atualização em tempo real'),
                    _buildFeatureItem('🔧', 'Teste de conexão integrado'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Spacer(),
            Center(
              child: Text(
                'Faculdade de Tecnologia SENAI Félix Guisard ❤',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(icon, style: TextStyle(fontSize: 18)),
          SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

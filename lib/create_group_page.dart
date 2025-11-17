import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Importação necessária para o Supabase
import 'main.dart'; // Ajuste conforme o caminho do seu arquivo main

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _nameController = TextEditingController();
  final List<String> _selectedUserIds = [];
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite o nome do grupo')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final creatorId = supabase.auth.currentUser?.id;
      if (creatorId == null) throw 'Usuário não autenticado';

      // 1) Cria o grupo
      final resp = await supabase
          .from('groups')
          .insert({
            'name': name,
            'owner_id': creatorId,
          })
          .select()
          .single();

      final String groupId = resp['id'] as String;

      // 2) Insere membros no group_members
      final members = <Map<String, dynamic>>[];

      // adiciona membros selecionados
      for (final id in _selectedUserIds) {
        members.add({'group_id': groupId, 'user_id': id});
      }

      // adiciona o criador automaticamente
      members.add({'group_id': groupId, 'user_id': creatorId});

      await supabase.from('group_members').insert(members);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grupo criado com sucesso!')),
        );

        Navigator.of(context).pop(true); // força recarregar lista
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar grupo: $e')),
        );
        Navigator.of(context).pop(false);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // 📥 FUNÇÃO CORRIGIDA: Buscar usuários incluindo 'name_account'
  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    final currentUserId = supabase.auth.currentUser!.id;
    final resp = await supabase
        .from('profiles')
        // 🎯 CORREÇÃO 1: Incluindo 'name_account' no select
        .select('id, name_account, username') 
        .neq('id', currentUserId);

    // Converte a resposta para o tipo esperado e ordena pelo nome da conta
    final users = List<Map<String, dynamic>>.from(resp);
    users.sort((a, b) {
      final aName = (a['name_account'] ?? a['username'] ?? '').toString().toLowerCase();
      final bName = (b['name_account'] ?? b['username'] ?? '').toString().toLowerCase();
      return aName.compareTo(bName);
    });

    return users;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Grupo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome do grupo'),
            ),
            const SizedBox(height: 12),
            const Text('Selecione os membros:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchUsers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: Text(
                            'Erro ao carregar usuários: ${snapshot.error}'));
                  }

                  final users = snapshot.data ?? [];

                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, i) {
                      final u = users[i];
                      final id = u['id'] as String;
                      
                      // 🎯 CORREÇÃO 2: Exibir 'name_account' com fallback para 'username' (email)
                      final displayName = u['name_account'] as String? ?? u['username'] as String? ?? 'Usuário Sem Nome';
                      
                      final selected = _selectedUserIds.contains(id);

                      return CheckboxListTile(
                        value: selected,
                        title: Text(displayName), // Exibe o nome da conta
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedUserIds.add(id);
                            } else {
                              _selectedUserIds.remove(id);
                            }
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _createGroup,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Criar Grupo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
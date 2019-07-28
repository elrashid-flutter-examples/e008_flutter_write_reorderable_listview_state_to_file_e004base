import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  Widget build(BuildContext context) {
    var materialApp = MaterialApp(
      title: 'MY APP',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: TasksPageWidget(),
    );
    return materialApp;
  }
}

class Tasks {
  static String apiEndpoint = "http://10.0.2.2:5011/api/Task/";

  static Future<List<TaskOpj>> allTasks() async {
    var response =
        await http.get(apiEndpoint, headers: await _getDefaultHeader());

    if (response.statusCode == 200) {
      final responseJson = json.decode(response.body);
      var list = new List<TaskOpj>();
      responseJson
          .forEach((element) => list.add(new TaskOpj.fromJson(element)));
      return list;
    } else {
      throw Exception('Failed to get Tasks');
    }
  }

  static Future<TaskOpj> getTask(String id) async {
    var response =
        await http.get(apiEndpoint + id, headers: await _getDefaultHeader());
    if (response.statusCode == 200) {
      final responseJson = json.decode(response.body);
      var opj = TaskOpj.fromJson(responseJson);
      return opj;
    } else {
      throw Exception('Failed to get Task with id = $id');
    }
  }

  static Future<TaskOpj> createTask(TaskOpj opj) async {
    var body = json.encode(opj);
    var response = await http.post(apiEndpoint,
        body: body, headers: await _getDefaultHeader());
    if (response.statusCode == 201) {
      final responseJson = json.decode(response.body);
      var opj = TaskOpj.fromJson(responseJson);
      return opj;
    } else {
      throw Exception('Failed to create Task \n $body');
    }
  }

  static Future<bool> updateTask(TaskOpj opj) async {
    var body = json.encode(opj);
    var response = await http.put(apiEndpoint + opj.guid,
        body: body, headers: await _getDefaultHeader());
    if (response.statusCode == 204) {
      return true;
    } else {
      throw Exception('Failed to update Task \n $body');
    }
  }

  static Future deleteTask(String id) async {
    var response =
        await http.delete(apiEndpoint + id, headers: await _getDefaultHeader());
    if (response.statusCode == 204) {
      return;
    } else {
      throw Exception('Failed to delete Task with id = $id');
    }
  }

  static Future<Map<String, String>> _getDefaultHeader(
      [Map<String, String> curentHeaders]) async {
    var headers = Map<String, String>();
    var jsonHeader = "application/json";
    headers['content-type'] = jsonHeader;
    if (curentHeaders != null) {
      curentHeaders.forEach((key, value) {
        headers[key] = value;
      });
    }

    return headers;
  }
}

class TaskOpj {
  String guid;
  String note;
  String createdAt;
  String modfiledAt;

  TaskOpj({this.guid, this.note, this.createdAt, this.modfiledAt});

  TaskOpj.fromJson(Map<String, dynamic> json) {
    guid = json['guid'];
    note = json['note'];
    createdAt = json['createdAt'];
    modfiledAt = json['modfiledAt'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['guid'] = this.guid;
    data['note'] = this.note;
    data['createdAt'] = this.createdAt;
    data['modfiledAt'] = this.modfiledAt;
    return data;
  }
}

class TasksPageWidget extends StatefulWidget {
  @override
  _TasksPageWidgetState createState() => _TasksPageWidgetState();
}

class _TasksPageWidgetState extends State<TasksPageWidget> {

  var tasks = List<TaskOpj>();

  List<String> tasksOrder;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future refresh() async {
    tasks = await Tasks.allTasks();
    await sortTasks();
    setState(() {});
  }

  Future sortTasks() async {
    if (tasks != null) {
      tasksOrder = await sortTasksGetState();
      var newList = List<TaskOpj>();
      for (var i = 0; i < tasksOrder.length; i++) {
        var task = tasks.firstWhere((t) => t.guid == tasksOrder[i],
            orElse: () => null);
        tasks.remove(task);
        if (task != null) {
          newList.add(task);
        }
      }
      newList.addAll(tasks);
      tasks = newList;
    }
  }

  Future sortTasksSaveState() async {
    await sortTasksSaveTofile(tasks.map((m) => m.guid).toList());
  }

  Future sortTasksSaveTofile(List<String> list) async {
    try {
      var listMap = List<Map<String, dynamic>>();
      for (var i = 0; i < list.length; i++) {
        var map = Map<String, dynamic>();
        map['order'] = i;
        map['guid'] = list[i];
        listMap.add(map);
      }

      Directory appDocDir = await getApplicationDocumentsDirectory();
      String appDocPath = appDocDir.path;
      var file = File(('$appDocPath/sortTasks.json'));
      var fileText = json.encode(listMap);
      file.writeAsStringSync(fileText);
    } catch (e) {
      print(e);
    }
  }

  Future<List<String>> sortTasksGetState() async {
    var list = List<String>();
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String appDocPath = appDocDir.path;
      var file = File(('$appDocPath/sortTasks.json'));
      var fileText = file.readAsStringSync();
      final jsonOpj = json.decode(fileText);
      jsonOpj
          .forEach((element) => list.insert(element['order'], element['guid']));
    } catch (e) {
      print(e);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Tasks"),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => refresh(),
          ),
        ],
      ),
      body: ReorderableListView(
        children: _children(),
        onReorder: _reorder,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              return TaskAddPageWidget(
                notifyParent: refresh,
              );
            },
          ),
        ),
        tooltip: 'add',
        child: Icon(Icons.add),
      ),
    );
  }

  List<Widget> _children() {
    var children = <Widget>[];
    for (final task in tasks)
      children.add(
        TaskWidget(
          key: Key(task.guid),
          taskOpj: task,
          notifyParent: refresh,
        ),
      );
    return children;
  }

  void _reorder(oldIndex, newIndex) {
    try {
      setState(() {
        if (newIndex > oldIndex) {
          newIndex -= 1;
        }
        final TaskOpj item = tasks.removeAt(oldIndex);
        tasks.insert(newIndex, item);
      });
      sortTasksSaveState();
    } catch (e) {
      print(e);
    }
  }


}

class TaskWidget extends StatelessWidget {
  final TaskOpj taskOpj;
  final Function() notifyParent;
  TaskWidget({Key key, @required this.taskOpj, @required this.notifyParent})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 10.0,
        bottom: 0.0,
      ),
      child: new Card(
        child: ListTile(
          leading: IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) {
                  return TaskEditPageWidget(
                    taskOpj: taskOpj,
                    notifyParent: notifyParent,
                  );
                },
              ),
            ),
          ),
          title: Text(taskOpj.note),
          subtitle: Text(taskOpj.guid),
          trailing: new IconButton(
            icon: Icon(Icons.delete),
            onPressed: () async {
              await Tasks.deleteTask(taskOpj.guid);
              Scaffold.of(context).hideCurrentSnackBar();
              Scaffold.of(context).showSnackBar(new SnackBar(
                content: new Text("Deleted note : " + taskOpj.guid),
              ));
              if (notifyParent != null) notifyParent();
            },
          ),
        ),
      ),
    );
  }
}

class TaskEditPageWidget extends StatefulWidget {
  final Function() notifyParent;
  final TaskOpj taskOpj;
  TaskEditPageWidget(
      {Key key, @required this.taskOpj, @required this.notifyParent})
      : super(key: key);

  @override
  _TaskEditPageWidgetState createState() => _TaskEditPageWidgetState();
}

class _TaskEditPageWidgetState extends State<TaskEditPageWidget> {
  TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController.fromValue(
      TextEditingValue(
        text: widget.taskOpj.note,
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(),
      body: _body(),
    );
  }

  Widget _appBar() {
    return AppBar(
      title: new Text("Edit Task"),
      actions: <Widget>[
        new IconButton(
          icon: new Icon(Icons.save),
          onPressed: _save,
        ),
      ],
    );
  }

  Widget _body() {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          Text("Note:"),
          TextField(
              decoration: InputDecoration(border: InputBorder.none),
              autofocus: true,
              keyboardType: TextInputType.multiline,
              maxLines: null,
              controller: _noteController),
        ],
      ),
    );
  }

  Future _save() async {
    widget.taskOpj.note = _noteController.text;
    await Tasks.updateTask(widget.taskOpj);
    widget.notifyParent();
    Navigator.pop(context);
  }
}

class TaskAddPageWidget extends StatefulWidget {
  final Function() notifyParent;
  TaskAddPageWidget({Key key, @required this.notifyParent}) : super(key: key);
  @override
  _TaskAddPageWidgetState createState() => _TaskAddPageWidgetState();
}

class _TaskAddPageWidgetState extends State<TaskAddPageWidget> {
  TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(),
      body: _body(),
    );
  }

  Widget _appBar() {
    return AppBar(
      title: new Text("Add Task"),
      actions: <Widget>[
        new IconButton(
          icon: new Icon(Icons.save),
          onPressed: _save,
        ),
      ],
    );
  }

  Widget _body() {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          Text("Note:"),
          TextField(
              decoration: InputDecoration(border: InputBorder.none),
              autofocus: true,
              keyboardType: TextInputType.multiline,
              maxLines: null,
              controller: _noteController),
        ],
      ),
    );
  }

  Future _save() async {
    var taskOpj = TaskOpj();
    taskOpj.note = _noteController.text;
    await Tasks.createTask(taskOpj);
    widget.notifyParent();
    Navigator.pop(context);
  }
}

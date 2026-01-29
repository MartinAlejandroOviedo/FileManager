import 'package:flutter/material.dart';
import 'package:file_manager/ui/app_icons.dart';

class DragDropDemo extends StatelessWidget {
  const DragDropDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drag & Drop Demo')),
      body: Center(
        child: DragTarget<String>(
          onAcceptWithDetails: (data) {},
          builder: (context, candidateData, rejectedData) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Draggable<String>(
                data: 'Archivo.txt',
                feedback: Material(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.blue,
                    child: const Text('Archivo.txt',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey[300],
                  child: const Text('Archivo.txt'),
                ),
              ),
              const SizedBox(width: 40),
              Container(
                width: 100,
                height: 100,
                color: Colors.green[100],
                child: Center(
                  child: Icon(AppIcons.folderOpen),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

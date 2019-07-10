import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:wanandroid_flutter/entity/todo_entity.dart';
import 'package:wanandroid_flutter/http/index.dart';
import 'package:wanandroid_flutter/page/notifications.dart';
import 'package:wanandroid_flutter/page/todo/todo_create.dart';
import 'package:wanandroid_flutter/res/index.dart';
import 'package:wanandroid_flutter/utils/index.dart';

class DataChangeNotification extends Notification {
  Datas data;
  bool removed;

  DataChangeNotification(this.data, {this.removed = false});
}

///to-do 列表页
class TodoListPage extends StatefulWidget {
  int type;
  int priority;
  int order;
  bool forceUpdate;

  TodoListPage(
    this.type,
    this.priority,
    this.order, {
    this.forceUpdate = false,
  }) {
    if (type == 0) {
      type = null;
    }
    if (priority == 0) {
      priority = null;
    }
    if (order == 0) {
      order = null;
    }
  }

  @override
  _TodoListPageState createState() => _TodoListPageState();
}

class _TodoListPageState extends State<TodoListPage> {
  List<Datas> datas;
  int currentPage;
  int totalPage;
  ScrollController _scrollController;
  bool isLoading;

  @override
  void initState() {
    super.initState();
    isLoading = false;
    currentPage ??= 1;
    totalPage ??= 1;
    _getTodoList(currentPage);
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      // 如果下拉的当前位置到scroll的最下面
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        if (currentPage < totalPage && !isLoading) {
          _getTodoList(currentPage + 1);
        }
      }
    });
  }

  @override
  void didUpdateWidget(TodoListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.priority != widget.priority ||
        oldWidget.type != widget.type ||
        oldWidget.order != widget.order ||
        widget.forceUpdate) {
      _refreshAuto();
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener(
      onNotification: (Notification notification) {
        switch (notification.runtimeType) {
          case UpdateNotification:
            if ((notification as UpdateNotification).update) {
              _refreshAuto();
            }
            return true; //没必要继续冒泡到todo_main
          case DataChangeNotification:
            if ((notification as DataChangeNotification).removed) {
              _deleteTodo((notification as DataChangeNotification).data);
            }
            return true;
        }
      },
      //todo 如何用代码控制RefreshIndicator拉出刷新头?
      child: RefreshIndicator(
          color: WColors.theme_color,
          child: ListView.builder(
            controller: _scrollController,
            physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            shrinkWrap: false,
            itemBuilder: (BuildContext context, int index) {
              if (datas == null || datas.length == 0) {
                return Container(
                  height: pt(400),
                  alignment: Alignment.center,
                  child: datas == null
                      ? CupertinoActivityIndicator()
                      : Text(
                          res.allEmpty,
                          style: TextStyle(fontSize: 18),
                        ),
                );
              } else {
                if (index != datas.length) {
                  return TodoItem(
                    index,
                    datas[index],
                  );
                } else {
                  return Container(
                    width: double.infinity,
                    height: pt(45),
                    alignment: Alignment.center,
                    child: (currentPage < totalPage)
                        ? CupertinoActivityIndicator()
                        : Text(
                            res.isBottomst,
                            style: TextStyle(color: WColors.hint_color),
                          ),
                  );
                }
              }
            },
            itemCount:
                (datas == null || datas.length == 0) ? 1 : datas.length + 1,
          ),
          onRefresh: _refreshAuto),
    );
  }

  Future<void> _refreshAuto() async {
    datas = null;
    currentPage = 1;
    totalPage = 1;
    await _getTodoList(currentPage);
  }

  ///获取todo列表
  Future _getTodoList(int page) async {
    isLoading = true;
    try {
      Response response = await TodoApi.getTodoList(
        page,
        type: widget.type,
        priority: widget.priority,
        orderby: widget.order,
      );
      TodoEntity entity = TodoEntity.fromJson(response.data);
      if (datas == null) {
        datas = entity.data.datas;
      } else {
        datas.addAll(entity.data.datas);
      }
      currentPage = entity.data.curPage;
      totalPage = entity.data.pageCount;
      print('_TodoListPageState : 获取todo列表成功');
    } catch (e) {
      DisplayUtil.showMsg(context, exception: e);
    }
    if (mounted) {
      setState(() {});
    }
    isLoading = false;
  }

  Future _deleteTodo(Datas data) async {
    isLoading = true;
    try {
      await TodoApi.deleteTodo(data.id);
      datas.remove(data);
      print('_TodoListPageState : 删除todo成功');
    } catch (e) {
      DisplayUtil.showMsg(context, exception: e);
    }
    if (mounted) {
      setState(() {});
    }
    isLoading = false;
  }
}

class TodoItem extends StatefulWidget {
  int index;
  Datas data;

  TodoItem(this.index, this.data);

  @override
  _TodoItemState createState() => _TodoItemState();
}

class _TodoItemState extends State<TodoItem> {
  BuildContext sc;

  @override
  Widget build(BuildContext context) {
    sc = context;
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, TodoCreatePage.ROUTER_NAME,
                arguments: widget.data)
            .then((needUpdate) {
          if (needUpdate ?? false) {
            //告诉_TodoListPageState要刷新列表
            UpdateNotification(true).dispatch(context);
          }
        });
      },
      onLongPress: () {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              content: Text(res.ensureDelete),
              actions: <Widget>[
                FlatButton(
                  child: Text(res.cancel),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                FlatButton(
                  child: Text(res.confirm),
                  onPressed: () {
                    DataChangeNotification(widget.data, removed: true)
                        .dispatch(this.context);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
      child: Container(
        alignment: Alignment.center,
        width: double.infinity,
        height: pt(65),
        margin: EdgeInsets.only(top: widget.index == 0 ? pt(30) : 0),
        child: Stack(
          overflow: Overflow.visible,
          alignment: Alignment.center,
          children: <Widget>[
            Positioned(
              left: widget.data.status == 1 ? null : -pt(45 / 2.0 + 70),
              //一个圆角半径+日期widget所占长度
              right: widget.data.status == 1 ? -pt(45 / 2.0 + 70) : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: pt(60),
                    alignment: Alignment.centerRight,
                    margin: EdgeInsets.only(right: pt(10)),
                    child: Text(
                      widget.data.completeDateStr,
                      maxLines: 1,
                      style: TextStyle(fontSize: 10, color: WColors.hint_color),
                    ),
                  ),
                  Container(
                    //一个疑问：一旦给contatiner加上alignment后，它的宽就固定为maxWidth了，这不是我想要的，所以目前只好给他的child再套上一个stack来实现内容垂直居中
                    constraints: BoxConstraints(
                      maxWidth: pt(375 - 70.0), //屏幕宽 - 日期widget长度
                      minWidth: pt(375 / 2.0 + 45 / 2.0), //一半屏幕宽 + 一个圆角半径
                      maxHeight: pt(45),
                      minHeight: pt(45),
                    ),
                    decoration: ShapeDecoration(
                      color: widget.data.status == 1
                          ? WColors.theme_color_light
                          : WColors.theme_color_dark,
                      shadows: <BoxShadow>[
                        DisplayUtil.supreLightElevation(
                          baseColor: widget.data.status == 1
                              ? WColors.theme_color_light.withAlpha(0xaa)
                              : WColors.theme_color_dark.withAlpha(0xaa),
                        ),
                      ],
                      shape: StadiumBorder(),
                    ),
//                  padding: EdgeInsets.symmetric(
//                    horizontal: pt(45 / 2.0 + 10),
//                  ),
                    child: Stack(
                      alignment: widget.data.status == 1
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: pt(45 / 2.0 + 5),
                          ),
                          child: Text(
                            widget.data.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          child: RotatedBox(
                            child: Image.asset(
                              'images/pull.png',
                              width: pt(20),
                              height: pt(20),
                              color: Colors.white30,
                            ),
                            quarterTurns: 3,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          child: RotatedBox(
                            child: Image.asset(
                              'images/pull.png',
                              width: pt(20),
                              height: pt(20),
                              color: Colors.white30,
                            ),
                            quarterTurns: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: pt(60),
                    margin: EdgeInsets.only(left: pt(10)),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.data.completeDateStr,
                      maxLines: 1,
                      style: TextStyle(fontSize: 10, color: WColors.hint_color),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

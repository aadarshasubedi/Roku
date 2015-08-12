﻿Imports System
Imports System.Collections.Generic
Imports System.Reflection
Imports Roku.Node


Namespace Util

    Public Class Traverse

        Public Shared Iterator Function Fields(
                x As Object,
                Optional flag As BindingFlags = BindingFlags.FlattenHierarchy Or BindingFlags.Public Or BindingFlags.NonPublic Or BindingFlags.Instance Or BindingFlags.GetField
            ) As IEnumerable(Of Tuple(Of Object, FieldInfo))

            If x Is Nothing Then Return

            If TypeOf x Is Array Then

                Dim xs = CType(x, Array)
                For i = 0 To xs.Length - 1

                    Yield New Tuple(Of Object, FieldInfo)(xs.GetValue(i), Nothing)
                Next
            Else
                For Each m In x.GetType.GetFields(flag)

                    Yield Tuple.Create(m.GetValue(x), m)
                Next
            End If

        End Function

        Public Shared Sub Nodes(
                node As INode,
                callback As Action(Of INode, String, INode, Boolean)
            )

            Traverse.Nodes(node,
                Function(parent, ref, child, isfirst)

                    callback(parent, ref, child, isfirst)
                    Return isfirst
                End Function)

        End Sub

        Public Shared Sub Nodes(
                node As INode,
                callback As Func(Of INode, String, INode, Boolean, Boolean)
            )

            Dim mark As New Dictionary(Of Integer, Boolean)
            Traverse.Nodes(node,
                Function(parent, ref, child)

                    Dim child_hash = child.GetHashCode
                    Dim isfirst = Not mark.ContainsKey(child_hash)
                    If isfirst Then mark.Add(child_hash, True)
                    Return callback(parent, ref, child, isfirst)
                End Function)

        End Sub

        Public Shared Sub Nodes(
                node As INode,
                callback As Func(Of INode, String, INode, Boolean)
            )

            If node Is Nothing Then Return
            If Not callback(Nothing, "", node) Then Return

            Dim enum_nodes As Action(Of INode) =
                Sub(node_ As INode)

                    Dim f =
                        Sub(ref As String, v As INode)

                            If v Is Nothing Then Return
                            If callback(node_, ref, v) Then enum_nodes(v)
                        End Sub

                    Select Case True

                        Case TypeOf node_ Is BlockNode

                            Dim x = CType(node_, BlockNode)
                            f("Owner", x.Owner)
                            For i = 0 To x.Statements.Count - 1

                                f(String.Format("[{0}]", i), x.Statements(i))
                            Next
                            For Each key In x.Scope.Keys

                                f(String.Format("`{0}", key), x.Scope(key))
                            Next

                        Case TypeOf node_ Is LetNode

                            Dim x = CType(node_, LetNode)
                            f("Var", x.Var)
                            f("Expression", x.Expression)

                        Case TypeOf node_ Is ExpressionNode

                            Dim x = CType(node_, ExpressionNode)
                            f("Left", x.Left)
                            f("Right", x.Right)

                        Case TypeOf node_ Is FunctionCallNode

                            Dim x = CType(node_, FunctionCallNode)
                            f("Expression", x.Expression)
                            For i = 0 To x.Arguments.Length - 1

                                f(String.Format("[{0}]", i), x.Arguments(i))
                            Next
                    End Select
                End Sub
            enum_nodes(node)

        End Sub


    End Class

End Namespace

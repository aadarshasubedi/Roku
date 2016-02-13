Imports System.Collections.Generic
Imports Roku.Manager


Namespace Manager

    Public Class RkCall
        Inherits RkCode0
        Implements IReturnBind

        Public Sub New()

            Me.Operator = RkOperator.Call
        End Sub

        Public Overridable ReadOnly Property Arguments As New List(Of RkValue)
        Public Overridable Property [Return] As RkValue Implements IReturnBind.Return
        Public Overridable Property [Function] As RkFunction

    End Class

End Namespace

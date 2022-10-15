#include "TcpServer.hpp"
#include <iostream>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>

TcpServer::TcpServer()
{
    m_listen_socket = 0;
    m_client_socket = 0;
}
TcpServer::~TcpServer()
{
    end();
}
int TcpServer::set_blocking(SOCKET fd, bool blocking)
{
    unsigned long mode = blocking ? 0 : 1;
    int ret;
    ret = ioctlsocket(fd, FIONBIO, &mode);
    if (ret)
    {
        std::cerr << "TcpServer::set_blocking : could not set fd to blocking..." << std::endl;
        return -1;
    }
    return 0;
}
int TcpServer::init(uint16_t port)
{
    if (is_listening())
    {
        end();
    }
    int ret;
	// Initialize WinSock
	WSAData data;
	WORD ver = MAKEWORD(2, 2);
	int wsResult = WSAStartup(ver, &data);
	if (wsResult != 0)
	{
		std::cerr << "TcpServer::init : can't start Winsock, Err #" << wsResult << std::endl;
		return -1;
	}
    // Create socket
	m_listen_socket = socket(AF_INET, SOCK_STREAM, 0);
	if (m_listen_socket == INVALID_SOCKET)
	{
		std::cerr << "TcpServer::init : can't create socket, Err #" << WSAGetLastError() << std::endl;
		WSACleanup();
		return -1;
	}
    sockaddr_in hint;
    hint.sin_family = AF_INET;
    hint.sin_port = htons(port);
    hint.sin_addr.S_un.S_addr = INADDR_ANY;
    ret = 0;
    //ret = inet_pton(AF_INET, "0.0.0.0", &hint.sin_addr);
    if (ret < 0)
    {
        std::cerr << "TcpServer::init : inet_pton returned " << ret << std::endl;
        return ret;
    }
    // Bind the ip address and port to a socket
    ret = bind(m_listen_socket, (sockaddr *)(&hint), sizeof(hint));
    if (ret < 0)
    {
        std::cerr << "TcpServer::init : could not bind listen socket, bind returned " << ret << std::endl;
        return ret;
    }
    return 0;
}
void TcpServer::end()
{
    closesocket(m_listen_socket);
    closesocket(m_client_socket);
    WSACleanup();
}
int TcpServer::listen(bool blocking)
{
    int ret;
    ret = set_blocking(m_listen_socket, blocking);
    if (ret)
        return -1;
    ret = ::listen(m_listen_socket, SOMAXCONN);
    return ret;
}
int TcpServer::accept()
{
    SOCKET client_socket;
    sockaddr_in  client_address;
    socklen_t client_size = sizeof(client_address);
    client_socket = ::accept(m_listen_socket, (sockaddr *)(&client_address), &client_size);
    if (client_socket != INVALID_SOCKET && m_client_socket > 0)
        ::closesocket(m_client_socket);
    if (client_socket != INVALID_SOCKET)
        m_client_socket = client_socket;
    return client_socket != INVALID_SOCKET ? 1 : 0;
}
int TcpServer::recv(void *ptr_buf, int size, bool blocking)
{
    int ret;
    ret = set_blocking(m_client_socket, blocking);
    if (ret)
        return -1;
    ret = ::recv(m_client_socket, (char *)ptr_buf, size, 0);
    if (ret < 0)
    {
        int wsa_error = WSAGetLastError();
        if (wsa_error == WSAEWOULDBLOCK)
            ret = 0;
    }
    return ret;
}
int TcpServer::send(const void *ptr_buf, int size)
{
    int ret;
    ret = ::send(m_client_socket, (const char *)ptr_buf, size, 0);
    return ret;
}

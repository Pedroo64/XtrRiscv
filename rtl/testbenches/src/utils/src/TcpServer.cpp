#include <iostream>
#include "TcpServer.hpp"
#ifdef WIN32
#include <ws2tcpip.h>
#else
#include <netinet/in.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#endif

TcpServer::TcpServer() : m_listen_socket(0), m_client_socket(0) {

}
TcpServer::~TcpServer() {
    end();
}
int TcpServer::set_blocking(socket_t fd, bool blocking) {
    unsigned long mode = blocking ? 0 : 1;
#ifdef WIN32
    if (ioctlsocket(fd, FIONBIO, &mode)) {
        std::cerr << "TcpServer::set_blocking : could not set fd to blocking..." << std::endl;
        return -1;
    }
    return 0;
#else
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags == -1) return -1;
    flags = blocking ? (flags & ~O_NONBLOCK) : (flags | O_NONBLOCK);
    flags = fcntl(fd, F_SETFL, flags);
    if (flags) {
        std::cerr << "TcpServer::set_blocking : could not set fd to blocking... err = " << flags << std::endl;
        return -1;
    }
#endif
    return 0;
}
int TcpServer::init(uint16_t port) {
    int ret;
    if (is_listening()) {
        end();
    }
#ifdef WIN32
    // Initialize WinSock
    WSAData data;
    WORD ver = MAKEWORD(2, 2);
    ret = WSAStartup(ver, &data);
    if (ret != 0) {
        std::cerr << "TcpServer::init: can't start Winsock, Err #" << ret << std::endl;
        return -1;
    }
#endif
    m_listen_socket = socket(AF_INET, SOCK_STREAM, 0);
    if (m_listen_socket == INVALID_SOCKET) {
#ifdef WIN32
        std::cerr << "TcpServer::init: can't create socket, Err #" << WSAGetLastError() << std::endl;
        WSACleanup();
#else
        std::cerr << "TcpServer::init: can't create socket." << std::endl;
#endif
        return -2;
    }

    sockaddr_in hint;
    hint.sin_family = AF_INET;
    hint.sin_port = htons(port);
#ifdef WIN32
    hint.sin_addr.S_un.S_addr = INADDR_ANY;
#else
    inet_pton(AF_INET, "0.0.0.0", &hint.sin_addr);
#endif
    ret = bind(m_listen_socket, (sockaddr *)(&hint), sizeof(hint));
    if (ret < 0) {
        std::cerr << "TcpServer::init: could not bind listen socket, bind returned " << ret << std::endl;
        return -3;
    }
    return 0;
}
int TcpServer::end() {
#ifdef WIN32
    closesocket(m_listen_socket);
    closesocket(m_client_socket);
    WSACleanup();
#else
    close(m_listen_socket);
    close(m_client_socket);
#endif
    return 0;
}
int TcpServer::listen(bool blocking) {
    if (set_blocking(m_listen_socket, blocking)) {
        std::cerr << "TcpServer::listen: could not set blocking" << std::endl;
        return -1;
    }
    return ::listen(m_listen_socket, SOMAXCONN);
}
int TcpServer::accept() {
    socket_t client_socket;
    sockaddr_in  client_address;
    socklen_t client_size = sizeof(client_address);
    client_socket = ::accept(m_listen_socket, (sockaddr *)(&client_address), &client_size);
    if (client_socket != INVALID_SOCKET && m_client_socket > 0)
        this->close(m_client_socket);
    if (client_socket != INVALID_SOCKET)
        m_client_socket = client_socket;
    return client_socket != INVALID_SOCKET ? 1 : 0;
}
int TcpServer::recv(void *ptr_buf, size_t size, bool blocking) {
    int ret;
    ret = set_blocking(m_client_socket, blocking);
    if (ret)
        return -1;
    ret = ::recv(m_client_socket, (char *)ptr_buf, size, 0);
    if (ret < 0)
    {
#ifdef WIN32
        int wsa_error = WSAGetLastError();
        if (wsa_error == WSAEWOULDBLOCK)
            ret = 0;
#else
        if (errno == EAGAIN && !blocking) {
            ret = 0;
        } else {
            std::cerr << "Error on socket: ret = " << ret << ", errno = " << errno << " " << strerror(errno) << std::endl;
        }
#endif
    }
    return ret;
}
int TcpServer::send(const void *ptr_buf, size_t size) {
    int ret;
    ret = ::send(m_client_socket, (const char *)ptr_buf, size, 0);
    return ret;
}